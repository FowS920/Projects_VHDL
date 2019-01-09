library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.all;
use work.mini_riscv_pkg.all;

entity rv_pc is
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
end entity rv_pc;

architecture RTL of rv_pc is

	-- Adder necessary for Program Counter Addition
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

	-- Internal out_pc
	signal out_pc_i : std_logic_vector(XLEN - 1 downto 0);

	-- Next out_pc_i
	signal out_pc_i_p0 : std_logic_vector(XLEN - 1 downto 0);

	-- Program Counter Addition
	signal pc_add : std_logic_vector(XLEN downto 0);
	-- Program Counter Target
	signal pc_tar : std_logic_vector(XLEN - 1 downto 0);

begin

	out_pc <= out_pc_i;

	-- Clocked process (it updates out_pc_i)
	process(in_clk, in_rstn)
	begin
		if (in_rstn = '0') then
			out_pc_i <= std_logic_vector(to_unsigned(RESET_VECTOR, XLEN));
		elsif rising_edge(in_clk) then
			case in_stall is
				-- Update output
				when '0'    => out_pc_i <= out_pc_i_p0;
				-- Keep same output
				when '1'    => out_pc_i <= out_pc_i;
				-- Unstable
				when others => out_pc_i <= out_pc_i;
			end case;
		end if;
	end process;

	-- Program Counter Addition assignment
	pc_adder : rv_adder
		generic map(
			N => XLEN
		)
		port map(
			in_a    => out_pc_i,
			in_b    => std_logic_vector(to_unsigned(4, XLEN)),
			in_sign => '0',
			in_sub  => '0',
			out_sum => pc_add
		);

	-- Program Counter Target assignment
	pc_tar <= in_target;

	-- Program Counter multiplexor
	process(in_transfert, pc_add, pc_tar)
	begin
		case in_transfert is
			-- Next PC comes from addition
			when '0'    => out_pc_i_p0 <= pc_add(XLEN - 1 downto 0);
			-- Next PC comes from target
			when '1'    => out_pc_i_p0 <= pc_tar;
			-- Unstable
			when others => out_pc_i_p0 <= pc_add(XLEN - 1 downto 0);
		end case;
	end process;

end architecture RTL;
