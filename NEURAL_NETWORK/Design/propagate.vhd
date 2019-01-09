library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.all;
use work.globals.all;

entity propagate is
	generic(
		-- Address size (Must match memory's size)
		ADDR_SIZE : natural := 15
	);
	port(
		--+---------------------------------+
		--| Custom instruction interface
		--+---------------------------------+
		-- Clock
		clk             : in  std_logic;
		-- Reset
		reset           : in  std_logic;
		-- Clock enable
		clk_en          : in  std_logic;
		-- Reserved (31 downto 8) and Layer number (7 downto 0)
		dataa           : in  std_logic_vector(31 downto 0);
		-- column_counter (31 downto 16) line_counter (15 downto 0)
		datab           : in  std_logic_vector(31 downto 0);
		-- Address towards output location
		result          : out std_logic_vector(31 downto 0);
		-- Start custom instruction
		start           : in  std_logic;
		-- Custom instruction done
		done            : out std_logic;
		--+---------------------------------+

		--+---------------------------------+
		--| Memory Interface
		--+---------------------------------+
		-- Clock
		mem_clk         : in  std_logic;
		-- Reset
		mem_reset       : in  std_logic;
		-- Memory address
		mem_address     : out std_logic_vector(ADDR_SIZE - 1 downto 0);
		-- Chip select
		mem_chipselect  : out std_logic;
		-- Write '1' or Read '0'
		mem_write       : out std_logic;
		-- Data to read from memory
		mem_read_data   : in  std_logic_vector(31 downto 0);
		-- Data written to memory
		mem_write_data  : out std_logic_vector(31 downto 0);
		-- Byte enable
		mem_byteenable  : out std_logic_vector(3 downto 0);
		--+---------------------------------+

		--+---------------------------------+
		--| Specialized Heart Interface
		--+---------------------------------+
		-- Start generating sub_image
		sub_image_start : out std_logic;
		-- Stop generating sub_image
		sub_image_stop  : out std_logic;
		-- Sub image data
		-- sub_image_data  : in  STD16_LOGIC_VECTOR(15 downto 0);
		sub_image_data  : in  std_logic_vector(255 downto 0);
		-- Sub image pixel
		sub_image_pixel : out std_logic_vector(31 downto 0)
		--+---------------------------------+
	);
end entity propagate;

architecture RTL of propagate is

	-- Synchronise custom instruction initiation
	signal start_q0 : std_logic;
	signal start_q1 : std_logic;

	signal mem_start : std_logic;

	-- Synchronise custom instruction done
	signal done_i : std_logic;

	signal mem_done    : std_logic;
	signal mem_done_q0 : std_logic;
	signal mem_done_q1 : std_logic;

	-- State machine next state updates
	type memory_access_states is (
		IDLE,
		LOAD_LAYER_ADDR, LOAD_INPUT_ADDR, LOAD_VALUE_ADDR, LOAD_LAYER_INFO,
		DATA_BIAS, DATA_WEIGHTS, DATA_CALCULATE, DATA_DELAY, DATA_DELAY_2, DATA_STORE,
		UNSTABLE
	);

	signal memory_access_state_p0 : memory_access_states;
	signal memory_access_state    : memory_access_states;
	signal memory_access_state_q0 : memory_access_states;

	-- State machine next memory address updates
	signal mem_address_p0 : std_logic_vector(ADDR_SIZE - 1 downto 0);

	signal mem_address_i : std_logic_vector(ADDR_SIZE - 1 downto 0);

	-- State machine next memory access updates 
	type memory_access is record
		addr   : std_logic_vector(ADDR_SIZE - 1 downto 0);
		cursor : std_logic_vector(ADDR_SIZE - 1 downto 0);
	end record;

	signal mem_access_layer_p0 : memory_access;
	signal mem_access_layer    : memory_access;
	signal mem_access_input_p0 : memory_access;
	signal mem_access_input    : memory_access;
	signal mem_access_value_p0 : memory_access;
	signal mem_access_value    : memory_access;

	-- State machine next counter signals update
	signal cnt_layer_p0 : std_logic_vector(31 downto 0);
	signal cnt_layer    : std_logic_vector(31 downto 0);

	signal cnt_input_p0 : std_logic_vector(31 downto 0);
	signal cnt_input    : std_logic_vector(31 downto 0);

	signal cnt_input_modulo_p0 : std_logic_vector(4 downto 0);
	signal cnt_input_modulo    : std_logic_vector(4 downto 0) := (others => '0');

	signal cnt_input_table_p0 : std_logic_vector(3 downto 0);
	signal cnt_input_table    : std_logic_vector(3 downto 0) := (others => '0');

	signal cnt_value_p0 : std_logic_vector(31 downto 0);
	signal cnt_value    : std_logic_vector(31 downto 0);

	signal cnt_value_modulo_p0 : std_logic_vector(4 downto 0);
	signal cnt_value_modulo    : std_logic_vector(4 downto 0) := (others => '0');

	-- State machine next number signals update
	signal nb_layer_p0 : std_logic_vector(31 downto 0);
	signal nb_layer    : std_logic_vector(31 downto 0);
	signal nb_input_p0 : std_logic_vector(31 downto 0);
	signal nb_input    : std_logic_vector(31 downto 0);
	signal nb_value_p0 : std_logic_vector(31 downto 0);
	signal nb_value    : std_logic_vector(31 downto 0);

	-- State machine next value calculated signal update
	signal value_calculated_p0 : std_logic_vector(31 downto 0);
	signal value_calculated    : std_logic_vector(31 downto 0);

	-- State machine next calculated values signal update
	signal calculated_values_p0 : std_logic_vector(31 downto 0);
	signal calculated_values    : std_logic_vector(31 downto 0);

	component propagate_calculate is
		port(
			-- Inputs for calculation
			inputs  : in  std_logic_vector(15 downto 0);
			-- Weights for calculation
			weights : in  std_logic_vector(31 downto 0);
			-- Calculate value
			value   : out std_logic_vector(31 downto 0)
		);
	end component propagate_calculate;

	-- Inputs for calculation
	signal inputs  : std_logic_vector(15 downto 0);
	-- Weights for calculation
	signal weights : std_logic_vector(31 downto 0);
	-- Calculate value
	signal value   : std_logic_vector(31 downto 0);

	-- Output registers
	signal mem_chipselect_p0 : std_logic;
	signal mem_write_p0      : std_logic;

begin

	-- Synchronise custom instruction initiation
	process(mem_clk, mem_reset)
	begin
		if (mem_reset = '1') then
			start_q0 <= '0';
			start_q1 <= '0';
		elsif rising_edge(mem_clk) then
			start_q0 <= start;
			start_q1 <= start_q0;
		end if;
	end process;

	mem_start <= start_q0 and not start_q1;

	-- Clocked process for all of the state machine
	process(mem_clk, mem_reset)
	begin
		if (mem_reset = '1') then
			memory_access_state    <= IDLE;
			memory_access_state_q0 <= IDLE;

			mem_address_i <= (others => '0');

			mem_access_layer <= ((others => '0'), (others => '0'));
			mem_access_input <= ((others => '0'), (others => '0'));
			mem_access_value <= ((others => '0'), (others => '0'));

			cnt_layer <= (others => '0');

			cnt_input <= (others => '0');

			cnt_input_modulo <= (others => '0');

			cnt_input_table <= (others => '0');

			cnt_value <= (others => '0');

			cnt_value_modulo <= (others => '0');

			nb_layer <= (others => '0');
			nb_input <= (others => '0');
			nb_value <= (others => '0');

			value_calculated <= (others => '0');

			calculated_values <= (others => '0');
		elsif rising_edge(mem_clk) then
			memory_access_state    <= memory_access_state_p0;
			memory_access_state_q0 <= memory_access_state;

			mem_address_i <= mem_address_p0;

			mem_access_layer <= mem_access_layer_p0;
			mem_access_input <= mem_access_input_p0;
			mem_access_value <= mem_access_value_p0;

			cnt_layer <= cnt_layer_p0;

			cnt_input <= cnt_input_p0;

			cnt_input_modulo <= cnt_input_modulo_p0;

			cnt_input_table <= cnt_input_table_p0;

			cnt_value <= cnt_value_p0;

			cnt_value_modulo <= cnt_value_modulo_p0;

			nb_layer <= nb_layer_p0;
			nb_input <= nb_input_p0;
			nb_value <= nb_value_p0;

			value_calculated <= value_calculated_p0;

			calculated_values <= calculated_values_p0;
		end if;
	end process;

	-- State machine next state updates
	process(mem_start, cnt_input, nb_input, cnt_value, nb_value, cnt_layer, nb_layer, memory_access_state)
		variable idle_nxt_v           : memory_access_states;
		variable data_calculate_nxt_v : memory_access_states;
		variable data_store_nxt_v     : memory_access_states;
	begin
		case mem_start is
			when '0' =>
				idle_nxt_v := IDLE;
			when '1' =>
				idle_nxt_v := LOAD_VALUE_ADDR;
			when others =>
				idle_nxt_v := IDLE;
		end case;

		if (cnt_input >= nb_input) then
			if (cnt_value >= nb_value) then
				data_calculate_nxt_v := DATA_DELAY;
			else
				if (cnt_value(4 downto 0) = "00000") then
					data_calculate_nxt_v := DATA_DELAY;
				else
					data_calculate_nxt_v := DATA_BIAS;
				end if;
			end if;
		else
			data_calculate_nxt_v := DATA_WEIGHTS;
		end if;

		if (cnt_value >= nb_value) then
			if (cnt_layer >= nb_layer) then
				data_store_nxt_v := IDLE;
			else
				data_store_nxt_v := LOAD_LAYER_ADDR;
			end if;
		else
			data_store_nxt_v := DATA_BIAS;
		end if;

		case memory_access_state is
			when IDLE            => memory_access_state_p0 <= idle_nxt_v;
			when LOAD_LAYER_ADDR => memory_access_state_p0 <= LOAD_INPUT_ADDR;
			when LOAD_INPUT_ADDR => memory_access_state_p0 <= LOAD_VALUE_ADDR;
			when LOAD_VALUE_ADDR => memory_access_state_p0 <= LOAD_LAYER_INFO;
			when LOAD_LAYER_INFO => memory_access_state_p0 <= DATA_BIAS;
			when DATA_BIAS       => memory_access_state_p0 <= DATA_WEIGHTS;
			when DATA_WEIGHTS    => memory_access_state_p0 <= DATA_CALCULATE;
			when DATA_CALCULATE  => memory_access_state_p0 <= data_calculate_nxt_v;
			when DATA_DELAY      => memory_access_state_p0 <= DATA_DELAY_2;
			when DATA_DELAY_2    => memory_access_state_p0 <= DATA_STORE;
			when DATA_STORE      => memory_access_state_p0 <= data_store_nxt_v;
			when others          => memory_access_state_p0 <= IDLE;
		end case;
	end process;

	-- State machine next memory address updates
	process(mem_address_i, memory_access_state, mem_start, mem_read_data, mem_access_input.cursor, cnt_input, nb_input, cnt_value, nb_value, mem_access_value.cursor, mem_access_layer.cursor, cnt_layer, nb_layer, mem_access_layer.addr)
	begin
		-- Default
		mem_address_p0 <= mem_address_i;

		case memory_access_state is
			when IDLE =>
				case mem_start is
					when '0' =>
						mem_address_p0 <= (others => '0');
					when '1' =>
						mem_address_p0 <= std_logic_vector(to_unsigned(1, ADDR_SIZE));
					when others =>
						mem_address_p0 <= (others => '0');
				end case;
			when LOAD_LAYER_ADDR =>
				mem_address_p0 <= std_logic_vector(unsigned(mem_address_i) + to_unsigned(1, ADDR_SIZE));
			when LOAD_INPUT_ADDR =>
				mem_address_p0 <= std_logic_vector(unsigned(mem_read_data(ADDR_SIZE - 1 downto 0)) + to_unsigned(1, ADDR_SIZE));
			when LOAD_VALUE_ADDR =>
				mem_address_p0 <= std_logic_vector(unsigned(mem_address_i) + to_unsigned(1, ADDR_SIZE));
			when LOAD_LAYER_INFO =>
				mem_address_p0 <= std_logic_vector(unsigned(mem_address_i) + to_unsigned(1, ADDR_SIZE));
			when DATA_BIAS =>
				mem_address_p0 <= std_logic_vector(unsigned(mem_address_i) + to_unsigned(1, ADDR_SIZE));
			when DATA_WEIGHTS =>
				mem_address_p0 <= mem_access_input.cursor;
			when DATA_CALCULATE =>
				if (cnt_input >= nb_input) then
					if (cnt_value >= nb_value) then
						mem_address_p0 <= mem_access_value.cursor;
					else
						if (cnt_value(4 downto 0) = "00000") then
							mem_address_p0 <= mem_access_value.cursor;
						else
							mem_address_p0 <= mem_access_layer.cursor;
						end if;
					end if;
				else
					mem_address_p0 <= mem_access_layer.cursor;
				end if;
			when DATA_DELAY =>
				mem_address_p0 <= mem_address_i;
			when DATA_DELAY_2 =>
				mem_address_p0 <= mem_address_i;
			when DATA_STORE =>
				if (cnt_value >= nb_value) then
					if (cnt_layer >= nb_layer) then
						mem_address_p0 <= (others => '0');
					else
						mem_address_p0 <= mem_access_layer.addr;
					end if;
				else
					mem_address_p0 <= mem_access_layer.cursor;
				end if;
			when others =>
				mem_address_p0 <= (others => '0');
		end case;
	end process;

	-- Multiply by four to access correctly 4 bytes
	mem_address <= mem_address_i(ADDR_SIZE - 1 - 2 downto 0) & "00";

	-- State machine next memory access updates
	process(mem_access_layer, mem_access_input, mem_access_value, memory_access_state_q0, mem_read_data, memory_access_state, cnt_input_modulo)
	begin
		-- Defaults
		mem_access_layer_p0 <= mem_access_layer;
		mem_access_input_p0 <= mem_access_input;
		mem_access_value_p0 <= mem_access_value;

		case memory_access_state_q0 is
			-- (IDLE ; LOAD_VALUE_ADDR)
			when IDLE =>
				case memory_access_state is
					when IDLE =>
						-- Pass
					when LOAD_VALUE_ADDR =>
						mem_access_layer_p0.addr   <= (others => '0');
						mem_access_layer_p0.cursor <= std_logic_vector(to_unsigned(2, ADDR_SIZE));
						mem_access_input_p0.addr   <= (others => '0');
						mem_access_input_p0.cursor <= (others => '0');
						mem_access_value_p0.addr   <= (others => '0');
						mem_access_value_p0.cursor <= (others => '0');
					when others =>
						-- Pass
				end case;
			-- (LOAD_INPUT_ADDR)
			when LOAD_LAYER_ADDR =>
				-- Load layer address and cursor
				mem_access_layer_p0.addr   <= mem_read_data(ADDR_SIZE - 1 downto 0);
				mem_access_layer_p0.cursor <= std_logic_vector(unsigned(mem_read_data(ADDR_SIZE - 1 downto 0)) + to_unsigned(1, ADDR_SIZE));
			-- (LOAD_VALUE_ADDR)
			when LOAD_INPUT_ADDR =>
				-- Read layer cursor and update
				mem_access_layer_p0.cursor <= std_logic_vector(unsigned(mem_access_layer.cursor) + to_unsigned(1, ADDR_SIZE));

				-- Load input address and cursor
				mem_access_input_p0.addr   <= mem_read_data(ADDR_SIZE - 1 downto 0);
				mem_access_input_p0.cursor <= mem_read_data(ADDR_SIZE - 1 downto 0);
			-- (LOAD_LAYER_INFO)
			when LOAD_VALUE_ADDR =>
				-- Read layer cursor and update
				mem_access_layer_p0.cursor <= std_logic_vector(unsigned(mem_access_layer.cursor) + to_unsigned(1, ADDR_SIZE));

				-- Load value address and cursor
				mem_access_value_p0.addr   <= mem_read_data(ADDR_SIZE - 1 downto 0);
				mem_access_value_p0.cursor <= mem_read_data(ADDR_SIZE - 1 downto 0);
			-- (DATA_BIAS)
			when LOAD_LAYER_INFO =>
				-- Read layer cursor and update
				mem_access_layer_p0.cursor <= std_logic_vector(unsigned(mem_access_layer.cursor) + to_unsigned(1, ADDR_SIZE));

				-- Reset input cursor
				mem_access_input_p0.cursor <= mem_access_input.addr;
			-- (DATA_WEIGHTS)
			when DATA_BIAS =>
				-- Read layer cursor and update
				mem_access_layer_p0.cursor <= std_logic_vector(unsigned(mem_access_layer.cursor) + to_unsigned(1, ADDR_SIZE));
			-- (DATA_CALCULATE)
			when DATA_WEIGHTS =>
				-- Read input cursor and update
				if (to_integer(unsigned(cnt_input_modulo)) = 0) then
					mem_access_input_p0.cursor <= mem_access_input.cursor;
				else
					mem_access_input_p0.cursor <= std_logic_vector(unsigned(mem_access_input.cursor) + to_unsigned(1, ADDR_SIZE));
				end if;
			-- (DATA_DELAY ; DATA_BIAS ; DATA_WEIGHTS)
			when DATA_CALCULATE =>
				case memory_access_state is
					when DATA_DELAY =>
						-- Reset input cursor
						mem_access_input_p0.cursor <= mem_access_input.addr;
					when DATA_BIAS =>
						-- Read layer cursor and update
						mem_access_layer_p0.cursor <= std_logic_vector(unsigned(mem_access_layer.cursor) + to_unsigned(1, ADDR_SIZE));

						-- Reset input cursor
						mem_access_input_p0.cursor <= mem_access_input.addr;
					when DATA_WEIGHTS =>
						-- Read layer cursor and update
						mem_access_layer_p0.cursor <= std_logic_vector(unsigned(mem_access_layer.cursor) + to_unsigned(1, ADDR_SIZE));
					when others =>
						-- Pass
				end case;
			-- (DATA_DELAY_2)
			when DATA_DELAY =>
				-- Pass
				-- (DATA_STORE)
			when DATA_DELAY_2 =>
				-- Write to value cursor and update
				mem_access_value_p0.cursor <= std_logic_vector(unsigned(mem_access_value.cursor) + to_unsigned(1, ADDR_SIZE));
			-- (IDLE ; LOAD_LAYER_ADDR ; DATA_BIAS)
			when DATA_STORE =>
				case memory_access_state is
					when IDLE =>
						-- Pass
					when LOAD_LAYER_ADDR =>
						-- Pass
					when DATA_BIAS =>
						-- Read layer cursor and update
						mem_access_layer_p0.cursor <= std_logic_vector(unsigned(mem_access_layer.cursor) + to_unsigned(1, ADDR_SIZE));
					when others =>
						-- Pass
				end case;
			when others =>
				-- Pass
		end case;
	end process;

	-- State machine next counter signals update
	process(cnt_layer, cnt_input, cnt_value, memory_access_state, mem_start)
	begin
		cnt_layer_p0 <= cnt_layer;
		cnt_input_p0 <= cnt_input;
		cnt_value_p0 <= cnt_value;

		case memory_access_state is
			when IDLE =>
				case mem_start is
					when '0' =>
						cnt_layer_p0 <= (others => '0');
						cnt_input_p0 <= (others => '0');
						cnt_value_p0 <= (others => '0');
					when '1' =>
						cnt_layer_p0 <= X"00000001";
						cnt_input_p0 <= X"00000000";
						cnt_value_p0 <= X"00000000";
					when others =>
						cnt_layer_p0 <= (others => '0');
						cnt_input_p0 <= (others => '0');
						cnt_value_p0 <= (others => '0');
				end case;
			when LOAD_LAYER_ADDR =>
				cnt_layer_p0 <= std_logic_vector(unsigned(cnt_layer) + to_unsigned(1, 32));
				cnt_input_p0 <= cnt_input;
				cnt_value_p0 <= X"00000000";
			when LOAD_INPUT_ADDR =>
				-- Pass
			when LOAD_VALUE_ADDR =>
				-- Pass
			when LOAD_LAYER_INFO =>
				-- Pass
			when DATA_BIAS =>
				cnt_layer_p0 <= cnt_layer;
				cnt_input_p0 <= X"00000000";
				cnt_value_p0 <= std_logic_vector(unsigned(cnt_value) + to_unsigned(1, 32));
			when DATA_WEIGHTS =>
				cnt_layer_p0 <= cnt_layer;
				cnt_input_p0 <= std_logic_vector(unsigned(cnt_input) + to_unsigned(16, 32));
				cnt_value_p0 <= cnt_value;
			when DATA_CALCULATE =>
				-- Pass
			when DATA_DELAY =>
				-- Pass
			when DATA_DELAY_2 =>
				-- Pass
			when DATA_STORE =>
				-- Pass
			when others =>
				-- Pass
		end case;
	end process;

	-- Modulo 32 of input being calculated (- 16)
	cnt_input_modulo_p0 <= std_logic_vector(signed(cnt_input_p0(4 downto 0)) - "10000");

	-- Division 16 of input being calculated (-1)
	cnt_input_table_p0 <= std_logic_vector(signed(cnt_input_p0(7 downto 4)) - "0001");

	-- Modulo 32 of value being calculated (- 1) (one cycle late, on purpose)
	-- Updated to fix an error (writing on last written bit again by accident...?)
	process(memory_access_state, memory_access_state_q0, cnt_value(4 downto 0))
	begin
		case memory_access_state is
			when DATA_BIAS =>
				case memory_access_state_q0 is
					when LOAD_LAYER_INFO => cnt_value_modulo_p0 <= (others => '0');
					when DATA_STORE      => cnt_value_modulo_p0 <= (others => '0');
					when others          => cnt_value_modulo_p0 <= std_logic_vector(signed(cnt_value(4 downto 0)) - "00001");
				end case;
			when DATA_STORE => cnt_value_modulo_p0 <= (others => '0');
			when others     => cnt_value_modulo_p0 <= std_logic_vector(signed(cnt_value(4 downto 0)) - "00001");
		end case;
	end process;

	-- State machine next number signals update
	process(nb_layer, nb_input, nb_value, memory_access_state_q0, mem_start, dataa, mem_read_data)
	begin
		nb_layer_p0 <= nb_layer;
		nb_input_p0 <= nb_input;
		nb_value_p0 <= nb_value;

		case memory_access_state_q0 is
			when IDLE =>
				case mem_start is
					when '0' =>
						nb_layer_p0 <= dataa(31 downto 0);
						nb_input_p0 <= (others => '0');
						nb_value_p0 <= (others => '0');
					when '1' =>
						nb_layer_p0 <= dataa(31 downto 0);
						nb_input_p0 <= X"00000000";
						nb_value_p0 <= X"00000000";
					when others =>
						nb_layer_p0 <= dataa(31 downto 0);
						nb_input_p0 <= (others => '0');
						nb_value_p0 <= (others => '0');
				end case;
			when LOAD_LAYER_ADDR =>
				-- Pass
			when LOAD_INPUT_ADDR =>
				-- Pass
			when LOAD_VALUE_ADDR =>
				-- Pass
			when LOAD_LAYER_INFO =>
				nb_layer_p0 <= nb_layer;
				nb_input_p0 <= X"0000" & mem_read_data(31 downto 16);
				nb_value_p0 <= X"0000" & mem_read_data(15 downto 0);
			when DATA_BIAS =>
				-- Pass
			when DATA_WEIGHTS =>
				-- Pass
			when DATA_CALCULATE =>
				-- Pass
			when DATA_DELAY =>
				-- Pass
			when DATA_DELAY_2 =>
				-- Pass
			when DATA_STORE =>
				-- Pass
			when others =>
				-- Pass
		end case;
	end process;

	-- State machine next value_calculated signal updates
	process(value_calculated, memory_access_state_q0, mem_read_data, value)
	begin
		-- Default
		value_calculated_p0 <= value_calculated;

		case memory_access_state_q0 is
			when IDLE =>
				-- Pass
			when LOAD_LAYER_ADDR =>
				-- Pass
			when LOAD_INPUT_ADDR =>
				-- Pass
			when LOAD_VALUE_ADDR =>
				-- Pass
			when LOAD_LAYER_INFO =>
				-- Pass
			when DATA_BIAS =>
				value_calculated_p0 <= mem_read_data(31 downto 0);
			when DATA_WEIGHTS =>
				-- Pass
			when DATA_CALCULATE =>
				value_calculated_p0 <= std_logic_vector(signed(value_calculated) + signed(value));
			when DATA_DELAY =>
				-- Pass
			when DATA_DELAY_2 =>
				value_calculated_p0 <= (others => '0');
			when DATA_STORE =>
				-- Pass
			when others =>
				-- Pass
		end case;
	end process;

	-- Determinate weights for xpropagate_calulate
	process(mem_clk, mem_reset)
	begin
		if (mem_reset = '1') then
			weights <= (others => '0');
		elsif rising_edge(mem_clk) then
			if (memory_access_state_q0 = DATA_WEIGHTS) then
				weights <= mem_read_data;
			else
				weights <= weights;
			end if;
		end if;
	end process;

	-- Determinate inputs for xpropagate_calculate
	process(cnt_input_modulo, cnt_input_table, cnt_layer, sub_image_data, mem_read_data)
		-- Convert cnt_value into an integer
		variable cnt_input_modulo_v : integer;
		-- Convert cnt_input_table into an integer
		variable cnt_input_table_v  : integer;
	begin
		cnt_input_modulo_v := to_integer(unsigned(cnt_input_modulo));
		cnt_input_table_v  := to_integer(unsigned(cnt_input_table));

		if (cnt_layer = X"00000001") then
			inputs <= sub_image_data((cnt_input_table_v * 16) + 15 downto (cnt_input_table_v * 16));
		else
			if (cnt_input_modulo_v = 0) then
				inputs <= mem_read_data(15 downto 0);
			else
				inputs <= mem_read_data(31 downto 16);
			end if;
		end if;
	end process;

	xpropagate_calculate : propagate_calculate
		port map(
			-- Inputs for calculation
			inputs  => inputs,
			-- Weights for calculation
			weights => weights,
			-- Calculate value
			value   => value
		);

	-- Generate calculated values
	gen_calculated_values : for i in 0 to 31 generate
		-- State machine next calculated values signal update
		process(cnt_value_modulo, memory_access_state_q0, calculated_values(i), value_calculated)
			-- Convert cnt_value into an integer
			variable cnt_value_modulo_v : integer;
		begin
			cnt_value_modulo_v := to_integer(unsigned(cnt_value_modulo));

			case memory_access_state_q0 is
				when IDLE =>
					calculated_values_p0(i) <= '0';
				when LOAD_LAYER_ADDR =>
					calculated_values_p0(i) <= '0';
				when LOAD_INPUT_ADDR =>
					calculated_values_p0(i) <= '0';
				when LOAD_VALUE_ADDR =>
					calculated_values_p0(i) <= '0';
				when LOAD_LAYER_INFO =>
					calculated_values_p0(i) <= '0';
				when DATA_BIAS | DATA_WEIGHTS | DATA_CALCULATE | DATA_DELAY | DATA_DELAY_2 =>
					if (i = cnt_value_modulo_v) then
						if (value_calculated = X"00000000") then
							calculated_values_p0(i) <= '0';
						else
							calculated_values_p0(i) <= not value_calculated(31);
						end if;
					else
						calculated_values_p0(i) <= calculated_values(i);
					end if;
				when DATA_STORE =>
					calculated_values_p0(i) <= '0';
				when others =>
					calculated_values_p0(i) <= '0';
			end case;
		end process;
	end generate gen_calculated_values;

	-- Only data to write is calculated values
	mem_write_data <= calculated_values;

	-- Return last values address
	result(31 downto ADDR_SIZE)    <= (others => '0');
	result(ADDR_SIZE - 1 downto 0) <= mem_access_value.addr;

	-- Synchronise custom instruction done
	process(mem_clk, mem_reset)
	begin
		if (mem_reset = '1') then
			mem_done    <= '0';
			mem_done_q0 <= '0';
			mem_done_q1 <= '0';
		elsif rising_edge(mem_clk) then
			if (memory_access_state_q0 = DATA_STORE and memory_access_state = IDLE) then
				mem_done <= '1';
			else
				mem_done <= '0';
			end if;

			mem_done_q0 <= mem_done and not done_i;
			mem_done_q1 <= mem_done_q0 and not done_i;
		end if;
	end process;

	process(clk, reset)
	begin
		if (reset = '1') then
			done_i <= '0';
		elsif rising_edge(clk) then
			if (done_i = '1') then
				done_i <= '0';
			else
				done_i <= mem_done or mem_done_q0 or mem_done_q1;
			end if;
		end if;
	end process;

	done <= done_i;

	-- Clocked process (it updates mem_chipselect and mem_write)
	process(mem_clk, mem_reset)
	begin
		if (mem_reset = '1') then
			mem_chipselect <= '0';
			mem_write      <= '0';
		elsif rising_edge(mem_clk) then
			mem_chipselect <= mem_chipselect_p0;
			mem_write      <= mem_write_p0;
		end if;
	end process;

	-- Update mem_chipselect output register
	with memory_access_state_p0 select mem_chipselect_p0 <=
		'0' when IDLE,
		'1' when others;

	-- Update mem_write output register
	with memory_access_state_p0 select mem_write_p0 <=
		'1' when DATA_STORE,
		'0' when others;

	-- Always use all bytes
	mem_byteenable <= (others => '1');

	-- Sub matrix done signal update
	--  process(cnt_layer, memory_access_state_q0)
	--  begin
	--		if (cnt_layer = X"00000001") then
	--			case memory_access_state_q0 is
	--				when DATA_CALCULATE =>
	--					sub_image_done <= '1';
	--				when others =>
	--					sub_image_done <= '0';
	--			end case;
	--		else
	--			sub_image_done <= '0';
	-- 		end if;
	--  end process;

	sub_image_start <= mem_start;

	sub_image_stop <= mem_done;

	sub_image_pixel <= datab;

end architecture RTL;
