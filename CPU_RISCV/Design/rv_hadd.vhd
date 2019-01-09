library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.all;

entity rv_hadd is
	port(
		in_a      : in  std_logic;
		in_b      : in  std_logic;
		out_sum   : out std_logic;
		out_carry : out std_logic);
end entity rv_hadd;

architecture RTL of rv_hadd is
begin

	out_sum   <= in_a XOR in_b;
	out_carry <= in_a AND in_b;

end architecture RTL;
