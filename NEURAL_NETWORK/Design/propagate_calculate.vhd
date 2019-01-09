library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.all;

entity propagate_calculate is
	port(
		-- Inputs for calculation
		inputs  : in  std_logic_vector(15 downto 0);
		-- Weights for calculation
		weights : in  std_logic_vector(31 downto 0);
		-- Calculate value
		value   : out std_logic_vector(31 downto 0)
	);
end entity propagate_calculate;

architecture RTL of propagate_calculate is

	type STD002_LOGIC_VECTOR is array (natural range <>) of std_logic_vector(1 downto 0);
	type STD008_LOGIC_VECTOR is array (natural range <>) of std_logic_vector(7 downto 0);

	-- Individual weights
	signal weight : STD002_LOGIC_VECTOR(15 downto 0) := (others => (others => '0'));

	-- Generate 1st addition branch
	signal value_1st : STD008_LOGIC_VECTOR(7 downto 0);
	-- Generate 2nd addition branch
	signal value_2nd : STD008_LOGIC_VECTOR(3 downto 0);
	-- Generate 3rd addition branch
	signal value_3rd : STD008_LOGIC_VECTOR(1 downto 0);
	-- Generate 4th addition branch
	signal value_4th : STD008_LOGIC_VECTOR(0 downto 0);

begin

	-- Update value at output
	value(6 downto 0) <= value_4th(0)(6 downto 0);

	gen_value : for i in 7 to 31 generate
		value(i) <= value_4th(0)(7);
	end generate gen_value;

	-- Split 16 weights into individual weights
	gen_weight : for i in 0 to 15 generate
		process(inputs, weights)
		begin
			case inputs(i) is
				-- Binary input is 0
				when '0' =>
					weight(i) <= "00";
				-- Binary input is 1
				when '1' =>
					weight(i) <= weights(1 + (2 * i) downto (2 * i));
				-- Unexpected
				when others =>
					weight(i) <= "00";
			end case;
		end process;
	end generate gen_weight;

	-- Generate 1st addition branch
	gen_value_1st : for i in 0 to 7 generate
		value_1st(i) <= std_logic_vector(to_signed(to_integer(signed(weight(i * 2))) + to_integer(signed(weight(i * 2 + 1))), 8));
	end generate gen_value_1st;

	-- Generate 2nd addition branch
	gen_value_2nd : for i in 0 to 3 generate
		value_2nd(i) <= std_logic_vector(signed(value_1st(i * 2)) + signed(value_1st(i * 2 + 1)));
	end generate gen_value_2nd;

	-- Generate 3rd addition branch
	gen_value_3rd : for i in 0 to 1 generate
		value_3rd(i) <= std_logic_vector(signed(value_2nd(i * 2)) + signed(value_2nd(i * 2 + 1)));
	end generate gen_value_3rd;

	-- Generate 4th addition branch
	gen_value_4th : for i in 0 to 0 generate
		value_4th(i) <= std_logic_vector(signed(value_3rd(i * 2)) + signed(value_3rd(i * 2 + 1)));
	end generate gen_value_4th;

end architecture RTL;
