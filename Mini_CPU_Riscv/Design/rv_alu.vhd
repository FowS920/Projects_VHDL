library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.all;
use work.mini_riscv_pkg.all;

entity rv_alu is
	generic(N : positive := 32);
	port(
		in_arith  : in  std_logic;
		in_sign   : in  std_logic;
		in_opcode : in  instruction;
		in_shamt  : in  std_logic_vector(SHAMT_WIDTH - 1 downto 0);
		in_src1   : in  std_logic_vector(XLEN - 1 downto 0);
		in_src2   : in  std_logic_vector(XLEN - 1 downto 0);
		out_res   : out std_logic_vector(XLEN - 1 downto 0)
	);
end entity rv_alu;

architecture RTL of rv_alu is

	component rv_adder is
		generic(N : positive := 32);
		port(
			in_a    : in  std_logic_vector(N - 1 downto 0);
			in_b    : in  std_logic_vector(N - 1 downto 0);
			in_sign : in  std_logic;
			in_sub  : in  std_logic;
			out_sum : out std_logic_vector(N downto 0));
	end component rv_adder;

	component rv_shifter is
		generic(N : positive := 5);
		port(
			in_data      : in  std_logic_vector(2**N - 1 downto 0);
			in_shamt     : in  std_logic_vector(N - 1 downto 0);
			in_arith     : in  std_logic;
			in_direction : in  std_logic;
			out_data     : out std_logic_vector(2**N - 1 downto 0));
	end component rv_shifter;

	-- Signals 
	signal adder_out   : std_logic_vector(N downto 0);
	signal shifter_out : std_logic_vector(N - 1 downto 0);
	signal direction   : std_logic;

begin

	adder : rv_adder
		generic map(N => ALUOP_WIDTH)
		port map(
			in_a    => in_src1,
			in_b    => in_src2,
			in_sign => in_sign,
			in_sub  => in_arith,
			out_sum => adder_out);

	direction <= '1' when ((in_opcode = ASM_SRLI) OR (in_opcode = ASM_SRAI) OR (in_opcode = ASM_SRL) OR (in_opcode = ASM_SRA)) else -- Verifier la direction du shift, en co moment 1 = gauche ?
	'0';

	shifter : rv_shifter
		generic map(N => 5)
		port map(
			in_data      => in_src1,
			in_shamt     => in_shamt,
			in_arith     => in_arith,
			in_direction => direction,
			out_data     => shifter_out);

	out_res <= adder_out(N - 1 downto 0) when ((in_opcode = ASM_ADDI) OR (in_opcode = ASM_ADD) OR (in_opcode = ASM_SUB) OR (in_opcode = ASM_SW) OR (in_opcode = ASM_LW) OR (in_opcode = ASM_JALR))
		else (N - 1 downto 1 => '0') & adder_out(N - 1) when ((in_opcode = ASM_SLT) OR (in_opcode = ASM_SLTU) OR (in_opcode = ASM_SLTI) OR (in_opcode = ASM_SLTIU))
		else shifter_out when ((in_opcode = ASM_SLL) OR (in_opcode = ASM_SRL) OR (in_opcode = ASM_SRA) OR (in_opcode = ASM_SLLI) OR (in_opcode = ASM_SRLI) OR (in_opcode = ASM_SRAI))
		else in_src1 XOR in_src2 when ((in_opcode = ASM_XOR) OR (in_opcode = ASM_XORI))
		else in_src1 OR in_src2 when ((in_opcode = ASM_OR) OR (in_opcode = ASM_ORI))
		else in_src1 AND in_src2 when ((in_opcode = ASM_AND) OR (in_opcode = ASM_ANDI))
		else in_src2 when ((in_opcode = ASM_LUI))
		else (others => '0');

end architecture RTL;
