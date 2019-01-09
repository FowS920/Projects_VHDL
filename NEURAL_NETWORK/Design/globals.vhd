library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package globals is
	type STD16_LOGIC_VECTOR is array (natural range <>) of std_logic_vector(15 downto 0);
end package;
