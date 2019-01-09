 library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- https://www.csee.umbc.edu/portal/help/VHDL/operator.html

-- http://www.bitweenie.com/wp-content/uploads/2013/02/vhdl-type-conversions.png

library work;
use work.all;
use work.globals.all;

entity sub_matrix is

	generic(
		ADDR_SIZE                      : integer               := 16;
		DATA_SIZE                      : integer               := 32;
		OUTPUT_SIZE                    : integer               := 16;
		S_CORE_MEM_BASE_ADDRESS        : unsigned(15 downto 0) := x"0000";
		S_CORE_MEM_PIXELS_ADDR_OFFSET  : unsigned(15 downto 0) := x"0001";
		IMAGE_WIDTH_VALUE_OFFSET       : integer               := 0;
		SUB_MATRIX_WIDTH_VALUE_OFFSET  : integer               := 16;
		SUB_MATRIX_HEIGHT_VALUE_OFFSET : integer               := 24
	);
	port(
		------------------
		-- BLOC MEMOIRE --
		------------------
		mem_clk          : in  std_logic;
		mem_reset        : in  std_logic;
		mem_read_data    : in  std_logic_vector((DATA_SIZE - 1) downto 0); -- what to read
		mem_chipselect   : out std_logic;
		mem_write        : out std_logic; -- write = 1, read = 0
		mem_address      : out std_logic_vector((ADDR_SIZE - 1) downto 0);
		mem_write_data   : out std_logic_vector((DATA_SIZE - 1) downto 0); -- what to write
		mem_byteenable   : out std_logic_vector((DATA_SIZE / 8) - 1 downto 0);
		------------------

		-----------------------------
		-- CONNEXION AU PROPAGATE --
		-----------------------------
		done             : in  std_logic;
		start            : in  std_logic;
		-- sub_matrix       : out STD16_LOGIC_VECTOR((OUTPUT_SIZE - 1) downto 0); -- le propagate ne peut reçevoir que OUTPUT_SIZE pixels (OUTPUT_SIZE bits)
		sub_matrix       : out  std_logic_vector(255 downto 0);
		sub_matrix_pixel : in  std_logic_vector(31 downto 0)
		-----------------------------
	);

end sub_matrix;

architecture RTL of sub_matrix is

	signal l_mem_address    : std_logic_vector((32 - 1) downto 0);
	signal l_mem_address_q0 : std_logic_vector((32 - 1) downto 0);

	signal image_width    : unsigned(15 downto 0); -- largeur de l'image current
	signal image_width_q0 : unsigned(15 downto 0); -- largeur de l'image last

	signal sub_matrix_width    : unsigned(15 downto 0); -- largeur de la sous-matrice current
	signal sub_matrix_width_q0 : unsigned(15 downto 0); -- largeur de la sous-matrice last

	signal sub_matrix_height    : unsigned(15 downto 0); -- hauteur de la sous-matrice current
	signal sub_matrix_height_q0 : unsigned(15 downto 0); -- hauteur de la sous-matrice last

	signal column_counter : unsigned(15 downto 0); -- compteur de colonnes dans la sous-matrice current
	signal line_counter   : unsigned(15 downto 0); -- compteur de lignes dans la sous-matrice last

	signal temporary : unsigned(15 downto 0); -- Valeur de shiftage n�cessaire

	signal i : unsigned(15 downto 0);   -- For loop i

	signal C0 : boolean;                -- Condition #1 (exit loop)
	signal C1 : boolean;                -- Condition #2 (need to fill up extra)

	-- signal l_sub_matrix : STD16_LOGIC_VECTOR((OUTPUT_SIZE - 1) downto 0);
	signal l_sub_matrix : std_logic_vector(255 downto 0);

	type sub_matrix_states is (IDLE, DIM_INIT, FOR_HEIGHT, TABLE_FILL_EXTRA, UNSTABLE);

	signal sub_matrix_state_p0 : sub_matrix_states; -- next
	signal sub_matrix_state    : sub_matrix_states; -- current
	signal sub_matrix_state_q0 : sub_matrix_states; -- last

begin

	sub_matrix <= l_sub_matrix;

	-------------------------
	-- MISE A JOUR MEMOIRE --
	-------------------------

	-- Always selected
	mem_chipselect <= '1';
	-- Never write
	mem_write      <= '0';
	-- MUL4 to get the proper address
	mem_address    <= l_mem_address(ADDR_SIZE - 1 - 2 downto 0) & "00";
	-- No data to ever write
	mem_write_data <= (others => '0');
	-- Always read all bytes
	mem_byteenable <= (others => '1');

	-- Take line counter
	line_counter   <= unsigned(sub_matrix_pixel(15 downto 0));
	-- Take column counter
	column_counter <= unsigned(sub_matrix_pixel(31 downto 16));
	
	-- Logic
	process(mem_clk, mem_reset)
	begin
		if (mem_reset = '1') then

			temporary      <= (others => '0');
			l_sub_matrix   <= (others => '0');
			i              <= (others => '0');
			C0             <= FALSE;
			C1             <= FALSE;

		elsif rising_edge(mem_clk) then

			case sub_matrix_state is

				when IDLE =>
					
					i <= (others => '0');
			
				when DIM_INIT =>

					i <= (others => '0');

					C0 <= TRUE;
					C1 <= FALSE;

					l_sub_matrix <= (others => '0');
					
					temporary <= (others => '0');

				when FOR_HEIGHT =>

					i <= i + 1;

					if (C0) then
						l_sub_matrix((to_integer(i) * 16) + 15 downto (to_integer(i) * 16)) <= std_logic_vector(shift_right(unsigned(mem_read_data(31 downto 0)), to_integer(((line_counter + i) * image_width + column_counter) mod to_unsigned(DATA_SIZE, 6)))(15 downto 0));
						C1                                                                  <= (unsigned(((line_counter + i) * image_width + column_counter) mod to_unsigned(DATA_SIZE, 16)) > 16);
					end if;
					
					temporary <= unsigned(((line_counter + i) * image_width + column_counter) mod to_unsigned(DATA_SIZE, 16)) ;

				when TABLE_FILL_EXTRA =>

					C0 <= (i < sub_matrix_height);

					if (C1) then
						l_sub_matrix((to_integer(i - 1) * 16) + 15 downto (to_integer(i - 1) * 16)) <= std_logic_vector(unsigned(l_sub_matrix((to_integer(i - 1) * 16) + 15 downto (to_integer(i - 1) * 16))) or shift_left(unsigned(mem_read_data(31 downto 0)), to_integer(32 - temporary))(15 downto 0));
					end if;

				when others =>

			end case;

		end if;

	end process;

	-- Update next signals
	process(mem_Clk, mem_reset)
	begin
		if (mem_reset = '1') then

			sub_matrix_state    <= IDLE;
			sub_matrix_state_q0 <= IDLE;

			l_mem_address_q0 <= (others => '0');

			image_width_q0       <= (others => '0');
			sub_matrix_width_q0  <= (others => '0');
			sub_matrix_height_q0 <= (others => '0');

		elsif rising_edge(mem_clk) then

			sub_matrix_state    <= sub_matrix_state_p0;
			sub_matrix_state_q0 <= sub_matrix_state;

			l_mem_address_q0 <= l_mem_address;

			image_width_q0       <= image_width;
			sub_matrix_width_q0  <= sub_matrix_width;
			sub_matrix_height_q0 <= sub_matrix_height;

		end if;

	end process;

	-- Update next state
	process(start, done, sub_matrix_state, C0)
	begin
		if (done = '1') then

			sub_matrix_state_p0 <= IDLE;

		else

			case sub_matrix_state is

				when IDLE =>

					if (start = '1') then

						sub_matrix_state_p0 <= DIM_INIT;
						
					else
					
						sub_matrix_state_p0 <= IDLE;

					end if;

				when DIM_INIT =>

					sub_matrix_state_p0 <= FOR_HEIGHT;

				when FOR_HEIGHT =>

					if (C0) then
						sub_matrix_state_p0 <= TABLE_FILL_EXTRA;
					else
						sub_matrix_state_p0 <= IDLE;
					end if;

				when TABLE_FILL_EXTRA =>

					sub_matrix_state_p0 <= FOR_HEIGHT;

				when others =>

					sub_matrix_state_p0 <= IDLE;

			end case;

		end if;

	end process;

	-- Update memory address to read from
	process(sub_matrix_state_p0, line_counter, image_width, column_counter, i, l_mem_address_q0)
	begin
		-- Default
		l_mem_address <= l_mem_address_q0;

		case sub_matrix_state_p0 is

			when DIM_INIT =>

				l_mem_address <= x"0000" & std_logic_vector(S_CORE_MEM_BASE_ADDRESS);

			when FOR_HEIGHT =>

				l_mem_address <= std_logic_vector(S_CORE_MEM_BASE_ADDRESS + S_CORE_MEM_PIXELS_ADDR_OFFSET + shift_right(((line_counter + i) * image_width + column_counter), 5));

			when TABLE_FILL_EXTRA =>

				l_mem_address <= std_logic_vector(unsigned(l_mem_address_q0) + to_unsigned(1, ADDR_SIZE));

			when others =>

				-- Pass

		end case;

	end process;

	-- Update informations
	process(sub_matrix_state, mem_read_data, image_width_q0, sub_matrix_width_q0, sub_matrix_height_q0)
	begin
		image_width       <= image_width_q0;
		sub_matrix_width  <= sub_matrix_width_q0;
		sub_matrix_height <= sub_matrix_height_q0;

		case sub_matrix_state is

			when DIM_INIT =>

				image_width       <= X"00" & unsigned(mem_read_data((7 + IMAGE_WIDTH_VALUE_OFFSET) downto IMAGE_WIDTH_VALUE_OFFSET));
				sub_matrix_width  <= X"00" & unsigned(mem_read_data((7 + SUB_MATRIX_WIDTH_VALUE_OFFSET) downto SUB_MATRIX_WIDTH_VALUE_OFFSET));
				sub_matrix_height <= X"00" & unsigned(mem_read_data((7 + SUB_MATRIX_HEIGHT_VALUE_OFFSET) downto SUB_MATRIX_HEIGHT_VALUE_OFFSET));

			when others =>

				-- Pass

		end case;

	end process;

end architecture RTL;
