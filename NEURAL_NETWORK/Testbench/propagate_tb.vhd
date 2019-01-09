library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.all;
use work.globals.all;

library std;
use std.textio.all;
use std.env.all;

entity propagate_tb is
end entity;

architecture testbench of propagate_tb is

	component propagate is
		generic(
			-- Address size (Must match memory's size)
			ADDR_SIZE : natural := 15
		);
		port(
			--+---------------------------------+A
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
			-- Reserved (31 downto 0)
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
			sub_image_data  : in  STD16_LOGIC_VECTOR(15 downto 0);
			-- Sub image pixel
			sub_image_pixel : out std_logic_vector(31 downto 0)
			--+---------------------------------+
		);
	end component propagate;

	component sub_matrix is
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
			mem_clk          : in    std_logic;
			mem_reset        : in    std_logic;
			mem_read_data    : in    std_logic_vector((DATA_SIZE - 1) downto 0); -- what to read
			mem_chipselect   : out   std_logic;
			mem_write        : out   std_logic; -- write = 1, read = 0
			mem_address      : out   std_logic_vector((ADDR_SIZE - 1) downto 0);
			mem_write_data   : out   std_logic_vector((DATA_SIZE - 1) downto 0); -- what to write
			mem_byteenable   : out   std_logic_vector((DATA_SIZE / 8) - 1 downto 0);
			-----------------------------
			-- CONNEXION AU PROPAGATE --
			-----------------------------
			done             : in    std_logic;
			start            : in    std_logic;
			sub_matrix       : inout STD16_LOGIC_VECTOR((OUTPUT_SIZE - 1) downto 0); -- le propagate ne peut reçevoir que OUTPUT_SIZE pixels (OUTPUT_SIZE bits)
			sub_matrix_pixel : in    std_logic_vector(31 downto 0)
		);
	end component sub_matrix;

	constant ADDR_SIZE : natural := 16;

	constant CLK_PERIOD     : time := 40 ns;
	constant MEM_CLK_PERIOD : time := 20 ns;

	--+---------------------------------+
	--| Custom instruction interface
	--+---------------------------------+
	-- Clock
	signal clk    : std_logic                     := '0';
	-- Reset
	signal reset  : std_logic                     := '1';
	-- Clock enable
	signal clk_en : std_logic                     := '0';
	-- Reserved (31 downto 8) and Layer number (7 downto 0)
	signal dataa  : std_logic_vector(31 downto 0) := (others => '0');
	-- Reserved (31 downto 0)
	signal datab  : std_logic_vector(31 downto 0) := (others => '0');
	-- Address towards output location
	signal result : std_logic_vector(31 downto 0);
	-- Start custom instruction
	signal start  : std_logic                     := '0';
	-- Custom instruction done
	signal done   : std_logic;
	--+---------------------------------+

	--+---------------------------------+
	--| Memory Interface
	--+---------------------------------+
	-- Clock
	signal mem_clk   : std_logic := '0';
	-- Reset
	signal mem_reset : std_logic := '1';

	-- Memory address
	signal mem_address    : std_logic_vector(ADDR_SIZE - 1 downto 0) := (others => '0');
	signal mem_address_q0 : std_logic_vector(ADDR_SIZE - 1 downto 0) := (others => '0');

	-- Chip select
	signal mem_chipselect : std_logic;
	-- Write '1' or Read '0'
	signal mem_write      : std_logic;
	-- Data to read from memory
	signal mem_read_data  : std_logic_vector(31 downto 0);
	-- Data written to memory
	signal mem_write_data : std_logic_vector(31 downto 0);
	-- Byte enable
	signal mem_byteenable : std_logic_vector(3 downto 0);
	--+---------------------------------+

	--+---------------------------------+
	--| Specialized Heart Interface
	--+---------------------------------+
	-- Start generating sub_image
	signal sub_image_start : std_logic;
	-- Stop generating sub_image
	signal sub_image_stop  : std_logic;
	-- Sub image data
	signal sub_image_data  : STD16_LOGIC_VECTOR(15 downto 0);
	-- Sub image pixel
	signal sub_image_pixel : std_logic_vector(31 downto 0);
	--+---------------------------------+

	-- Declare memory
	type data_size is array (natural range <>) of std_logic_vector(31 downto 0);

	signal memory : data_size(2**(ADDR_SIZE - 5) - 1 downto 0) := (852    => X"0028000A", 851 => X"000003CD", 850 => X"00000000", 687 => X"00280028", 686 => X"00000350", 685 => X"00000352",
	                                                               547    => X"00000111", 546 => X"55555555", 545 => X"00000000", 544 => X"00000000", 543 => X"00000000", 542 => X"00000000", 541 => X"00000000", 540 => X"00000000", 539 => X"00000000", 538 => X"00000000", 537 => X"00000000", 536 => X"00000000", 535 => X"00000000", 534 => X"00000000", 533 => X"00000000", 532 => X"00000000", 531 => X"00000000", 530 => X"FFFFFFFE",
	                                                               8      => X"55555555", 7 => X"00000000", 6 => X"00000000", 5 => X"00000000", 4 => X"00000000", 3 => X"FFFFFFFE", 2 => X"01000028", 1 => X"000002AB", 0 => X"000002AD", others => (others => '0')
	                                                              );

	signal memory_sub_image : data_size(2**(ADDR_SIZE - 5) - 1 downto 0) := (0 => X"1010003C", others => (others => '1')); -- 240 => X"0000BEEF", 16 => X"0000DEAD", 8 => X"C0FE0000", 1 => X"0000AD1B"

	-- Declare test table
	signal sub_image_test : STD16_LOGIC_VECTOR(15 downto 0) := (others => (others => '1')); -- (X"1337", X"BA11", X"BA5E", X"BEEF", X"DEAD", X"C0FE", X"0000", X"AD1B", X"1337", X"BA11", X"BA5E", X"BEEF", X"DEAD", X"C0FE", X"0000", X"AD1B");

	-- Sub image
	signal mem_read_data_sub_image : std_logic_vector(31 downto 0);

	signal mem_address_sub_image    : std_logic_vector(ADDR_SIZE - 1 downto 0);
	signal mem_address_q0_sub_image : std_logic_vector(ADDR_SIZE - 1 downto 0);

	signal mem_write_sub_image : std_logic;

	signal mem_write_data_sub_image : std_logic_vector(31 downto 0);

begin

	clk <= not clk after CLK_PERIOD / 2;

	mem_clk <= not mem_clk after MEM_CLK_PERIOD / 2;

	proc_testbench : process
	begin
		report "<<---- Simulation Start ---->>";

		wait for 100 ns;

		reset <= '0';

		mem_reset <= '0';

		wait for CLK_PERIOD;

		start <= '1';

		wait for CLK_PERIOD;

		start <= '0';

		wait until false;

		report "<<----- Simulation End ----->>";

		stop;
	end process;

	dataa <= std_logic_vector(to_unsigned(3, 32));
	datab <= (others => '0');

	-- #A
	process(mem_clk, mem_reset)
	begin
		if (mem_reset = '1') then
			mem_address_q0 <= (others => '0');
		elsif rising_edge(mem_clk) then
			mem_address_q0 <= mem_address;

			if (mem_write = '1') then
				memory(to_integer(unsigned(mem_address(ADDR_SIZE - 1 downto 2)))) <= mem_write_data;
			end if;
		end if;
	end process;

	mem_read_data <= memory(to_integer(unsigned(mem_address_q0(ADDR_SIZE - 1 downto 2))));

	-- sub_image_data <= sub_image_test;

	-- #B
	process(mem_clk, mem_reset)
	begin
		if (mem_reset = '1') then
			mem_address_q0_sub_image <= (others => '0');
		elsif rising_edge(mem_clk) then
			mem_address_q0_sub_image <= mem_address_sub_image;

			if (mem_write_sub_image = '1') then
				memory_sub_image(to_integer(unsigned(mem_address_sub_image(ADDR_SIZE - 1 downto 2)))) <= mem_write_data_sub_image;
			end if;
		end if;
	end process;

	mem_read_data_sub_image <= memory_sub_image(to_integer(unsigned(mem_address_q0_sub_image(ADDR_SIZE - 1 downto 2))));

	xsub_matrix : sub_matrix
		generic map(
			ADDR_SIZE                      => ADDR_SIZE,
			DATA_SIZE                      => 32,
			OUTPUT_SIZE                    => 16,
			S_CORE_MEM_BASE_ADDRESS        => X"0000",
			S_CORE_MEM_PIXELS_ADDR_OFFSET  => X"0001",
			IMAGE_WIDTH_VALUE_OFFSET       => 0,
			SUB_MATRIX_WIDTH_VALUE_OFFSET  => 16,
			SUB_MATRIX_HEIGHT_VALUE_OFFSET => 24
		)
		port map(
			------------------
			-- BLOC MEMOIRE --
			------------------
			mem_clk          => mem_clk,
			mem_reset        => mem_reset,
			mem_read_data    => mem_read_data_sub_image,
			mem_chipselect   => open,
			mem_write        => mem_write_sub_image,
			mem_address      => mem_address_sub_image,
			mem_write_data   => mem_write_data_sub_image,
			mem_byteenable   => open,
			-----------------------------
			-- CONNEXION AU PROPAGATE --
			-----------------------------
			done             => sub_image_stop,
			start            => sub_image_start,
			sub_matrix       => sub_image_data,
			sub_matrix_pixel => sub_image_pixel
		);

	xpropagate : propagate
		generic map(
			-- Address size (Must match memory's size)
			ADDR_SIZE => ADDR_SIZE
		)
		port map(
			--+---------------------------------+
			--| Custom instruction interface
			--+---------------------------------+
			-- Clock
			clk             => clk,
			-- Reset
			reset           => reset,
			-- Clock enable
			clk_en          => clk_en,
			-- Reserved (31 downto 8) and Layer number (7 downto 0)
			dataa           => dataa,
			-- Reserved (31 downto 0)
			datab           => datab,
			-- Address towards output location
			result          => result,
			-- Start custom instruction
			start           => start,
			-- Custom instruction done
			done            => done,
			--+---------------------------------+

			--+---------------------------------+
			--| Memory Interface
			--+---------------------------------+
			-- Clock
			mem_clk         => mem_clk,
			-- Reset
			mem_reset       => mem_reset,
			-- Memory address
			mem_address     => mem_address,
			-- Chip select
			mem_chipselect  => mem_chipselect,
			-- Write '1' or Read '0'
			mem_write       => mem_write,
			-- Data to read from memory
			mem_read_data   => mem_read_data,
			-- Data written to memory
			mem_write_data  => mem_write_data,
			-- Byte enable
			mem_byteenable  => mem_byteenable,
			--+---------------------------------+

			--+---------------------------------+
			--| Specialized Heart Interface
			--+---------------------------------+
			-- Start generating sub_image
			sub_image_start => sub_image_start,
			-- Stop generating sub_image
			sub_image_stop  => sub_image_stop,
			-- Sub image data
			sub_image_data  => sub_image_test, -- sub_image_data,
			-- Sub image pixel
			sub_image_pixel => sub_image_pixel
			--+---------------------------------+
		);

end architecture testbench;
