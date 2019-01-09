library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.all;

entity rv_adder is
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
end entity rv_adder;

architecture RTL of rv_adder is

	component rv_hadd is
		port(
			in_a      : in  std_logic;
			in_b      : in  std_logic;
			out_sum   : out std_logic;
			out_carry : out std_logic);
	end component;

	signal carry_to_a           : std_logic_vector(N downto 0);
	signal ctc_0, ctc_1         : std_logic_vector(N downto 0);
	signal sum_to_b             : std_logic_vector(N downto 0);
	signal sign_ex_a, sign_ex_b : std_logic_vector(N downto 0);
	signal twos_b               : std_logic_vector(N downto 0);

begin

	-- Sign-exten
	sign_ex_a <= in_a(N - 1) & in_a(N - 1 downto 0) when in_sign = '1' else '0' & in_a(N - 1 downto 0);

	sign_ex_b <= in_b(N - 1) & in_b(N - 1 downto 0) when in_sign = '1' else '0' & in_b(N - 1 downto 0);

	-- 2s complement

	twos_b <= not sign_ex_b when in_sub = '1' else sign_ex_b;

	-- Instanciate half-adders

	gen_hadd : for i in 0 to N generate

		gen_0 : if (i = 0) generate
			u_add : rv_hadd
				port map(
					in_a      => sign_ex_a(0),
					in_b      => twos_b(0),
					out_sum   => sum_to_b(0),
					out_carry => ctc_0(0));

			d_add : rv_hadd
				port map(
					in_a      => in_sub,
					in_b      => sum_to_b(0),
					out_sum   => out_sum(0),
					out_carry => ctc_1(0));

			carry_to_a(0) <= ctc_0(0) OR ctc_1(0);
		end generate gen_0;

		gen_i : if (i > 0 and i < N + 1) generate
			u_add : rv_hadd
				port map(
					in_a      => sign_ex_a(i),
					in_b      => twos_b(i),
					out_carry => ctc_0(i),
					out_sum   => sum_to_b(i));

			d_add : rv_hadd
				port map(
					in_a      => carry_to_a(i - 1),
					in_b      => sum_to_b(i),
					out_carry => ctc_1(i),
					out_sum   => out_sum(i));

			carry_to_a(i) <= ctc_0(i) OR ctc_1(i);
		end generate gen_i;

		gen_N : if (i = N + 1) generate
			u_add : rv_hadd
				port map(
					in_a      => sign_ex_a(i),
					in_b      => twos_b(i),
					out_carry => ctc_0(i),
					out_sum   => sum_to_b(i));

			d_add : rv_hadd
				port map(
					in_a      => carry_to_a(i),
					in_b      => sum_to_b(i),
					out_carry => ctc_1(i),
					out_sum   => out_sum(i));
		end generate gen_N;

		--out_sum(N) <= ctc_1(N-2);

	end generate gen_hadd;

end architecture RTL;
