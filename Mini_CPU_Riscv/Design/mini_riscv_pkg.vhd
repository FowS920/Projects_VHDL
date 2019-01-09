library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.all;

package mini_riscv_pkg is

	--+--------------------------------------------------+
	--| Commmon STD_LOGIC_VECTOR arrays
	--+--------------------------------------------------+
	type STD002_LOGIC_VECTOR is array (natural range <>) of std_logic_vector(1 downto 0);
	type STD004_LOGIC_VECTOR is array (natural range <>) of std_logic_vector(3 downto 0);
	type STD008_LOGIC_VECTOR is array (natural range <>) of std_logic_vector(7 downto 0);
	type STD016_LOGIC_VECTOR is array (natural range <>) of std_logic_vector(15 downto 0);
	type STD032_LOGIC_VECTOR is array (natural range <>) of std_logic_vector(31 downto 0);
	type STD064_LOGIC_VECTOR is array (natural range <>) of std_logic_vector(63 downto 0);
	type STD128_LOGIC_VECTOR is array (natural range <>) of std_logic_vector(127 downto 0);
	type STD256_LOGIC_VECTOR is array (natural range <>) of std_logic_vector(255 downto 0);
	--+--------------------------------------------------+

	--+--------------------------------------------------+
	--| Mini-Riscv instructions
	--+--------------------------------------------------+
	type instruction is (
		ASM_LUI, ASM_JAL, ASM_JALR, ASM_BEQ, ASM_LW, ASM_SW, ASM_ADDI,
		ASM_SLTI, ASM_SLTIU, ASM_XORI, ASM_ORI, ASM_ANDI, ASM_SLLI,
		ASM_SRLI, ASM_SRAI, ASM_ADD, ASM_SUB, ASM_SLL, ASM_SLT,
		ASM_SLTU, ASM_XOR, ASM_SRL, ASM_SRA, ASM_OR, ASM_AND, ASM_NOP
	);
	--+--------------------------------------------------

	--+--------------------------------------------------+
	--| Constants
	--+--------------------------------------------------+
	-- Length of data
	constant XLEN : natural := 32;

	-- Size of registers
	constant REG : natural := 5;

	-- Shamt's width
	constant SHAMT_WIDTH : natural := 5; -- 32 previously

	-- ALU operations' width
	constant ALUOP_WIDTH : natural := 32;
	--+--------------------------------------------------+

	--+--------------------------------------------------+
	--| Components
	--+--------------------------------------------------+
	-- Program Counter
	component rv_pc is
		generic(
			RESET_VECTOR : natural := 16#00000000#
		);
		port(
			in_clk       : in  std_logic;
			in_rstn      : in  std_logic;
			in_stall     : in  std_logic;
			in_transfert : in  std_logic;
			in_target    : in  std_logic_vector(XLEN - 1 downto 0);
			out_pc       : out std_logic_vector(XLEN - 1 downto 0)
		);
	end component rv_pc;

	-- Register File
	component rv_rf is
		port(
			in_clk      : in  std_logic;
			in_rstn     : in  std_logic;
			in_we       : in  std_logic;
			in_addr_ra  : in  std_logic_vector(REG - 1 downto 0);
			out_data_ra : out std_logic_vector(XLEN - 1 downto 0);
			in_addr_rb  : in  std_logic_vector(REG - 1 downto 0);
			out_data_rb : out std_logic_vector(XLEN - 1 downto 0);
			in_addr_w   : in  std_logic_vector(REG - 1 downto 0);
			in_data_w   : in  std_logic_vector(XLEN - 1 downto 0)
		);
	end component;

	-- ALU
	component rv_alu is
	    generic(
	        N : positive := 32
	    );
		port(
			in_arith  : in  std_logic;
			in_sign   : in  std_logic;
			in_opcode : in  instruction;
			in_shamt  : in  std_logic_vector(SHAMT_WIDTH - 1 downto 0);
			in_src1   : in  std_logic_vector(XLEN - 1 downto 0);
			in_src2   : in  std_logic_vector(XLEN - 1 downto 0);
			out_res   : out std_logic_vector(XLEN - 1 downto 0)
		);
	end component rv_alu;

	-- Core
	component rv_core is
		port(
			in_clk         : in  std_logic;
			in_rstn        : in  std_logic;
			in_imem_read   : in  std_logic_vector(31 downto 0);
			out_imem_addr  : out std_logic_vector(9 downto 0);
			in_dmem_read   : in  std_logic_vector(31 downto 0);
			out_dmem_we    : out std_logic;
			out_dmem_addr  : out std_logic_vector(9 downto 0);
			out_dmem_write : out std_logic_vector(31 downto 0)
		);
	end component rv_core;

	-- Adder
	component rv_adder is
		generic(
			N : positive := 32
		);
		port(
			in_a    : in  std_logic_vector(N - 1 downto 0);
			in_b    : in  std_logic_vector(N - 1 downto 0);
			in_sign : in  std_logic;
			in_sub  : in  std_logic;
			out_sum : out std_logic_vector(N downto 0)
		);
	end component rv_adder;

	-- Half-Adder
	component rv_hadd is
		port(
			in_a      : in  std_logic;
			in_b      : in  std_logic;
			out_sum   : out std_logic;
			out_carry : out std_logic);
	end component rv_hadd;

	-- Shifter
	component rv_shifter is
		generic(
			-- Data size in bits
			N : positive := 5
		);
		port(
			-- Data to shift
			in_data      : in  std_logic_vector(2**N - 1 downto 0);
			-- Number of bits to shift
			in_shamt     : in  std_logic_vector(N - 1 downto 0);
			-- Activation of arithmetic shift
			in_arith     : in  std_logic;
			-- Shift direction
			in_direction : in  std_logic;
			-- Shifted data
			out_data     : out std_logic_vector(2**N - 1 downto 0)
		);
	end component rv_shifter;

	component imem is
		generic(
			INIT_FILE  : string   := "../asm/init.hex";
			ADDR_WIDTH : positive := 10;
			DATA_WIDTH : positive := 32);
		port(
			in_addr  : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
			out_read : out std_logic_vector(DATA_WIDTH - 1 downto 0)
		);
	end component imem;

	component dmem is
		generic(
			ADDR_WIDTH : positive := 10;
			DATA_WIDTH : positive := 32);
		port(
			in_clk   : in  std_logic;
			in_we    : in  std_logic;
			in_addr  : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
			in_write : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
			out_read : out std_logic_vector(DATA_WIDTH - 1 downto 0)
		);
	end component dmem;
	--+--------------------------------------------------+

end package mini_riscv_pkg;

package body mini_riscv_pkg is
end package body mini_riscv_pkg;
