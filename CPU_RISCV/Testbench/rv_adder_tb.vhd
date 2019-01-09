library ieee; 
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

--library std;
--use std.textio.all;                                                      
--use std.env.all;

library work;
use work.all;
use work.mini_riscv_pkg.all;

entity rv_adder_tb is 
end rv_adder_tb;

architecture tb of rv_adder_tb is


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

  signal a, b : std_logic_vector(31 downto 0);
  signal sign, sub : std_logic;	
  signal sum : std_logic_vector(32 downto 0);

  constant PERIOD   : time := 10 ns;
  constant MAX_UNSIGNED : integer := 10;
  constant MIN_SIGNED : integer := -10;
  constant MAX_SIGNED : integer := 10;
  
begin

  -- DUT
  u_rv_adder : rv_adder
    generic map(N => 32)
    port map ( 
	in_a  	=> a,
   	in_b   	=> b,
	in_sign => sign,
	in_sub  => sub,
      	out_sum	=> sum
	);

  -- Main TB process
  do_tb : process
    variable i : integer := 0;
    variable j : integer := 0;
  begin
    report "<<---- Simulation Start ---->>";

	a <= (others=>'0'); --  Set everything to zero
	b <= (others=>'0');
	sign <= '0';
	sub <= '0';
	wait for PERIOD;

	-- Testing for unsigned addition
	-- Extensive testing would be from 0 up to (2**32)-1 for i and j
	report "Testing unsigned addition";
	while (i /= MAX_UNSIGNED) loop 
		wait for PERIOD;
		j:= 0;
		while(j /= MAX_UNSIGNED) loop 
			wait for PERIOD;
			a <= std_logic_vector(to_unsigned(i, 32));
			b <= std_logic_vector(to_unsigned(j, 32));

			assert to_integer(unsigned(sum)) = to_integer(unsigned(a)) + to_integer(unsigned(b))
				report "Error at a = " & integer'image(to_integer(unsigned(a))) & " and b = " & integer'image(to_integer(unsigned(b)));
			j:= j+1;
		end loop;
		i:= i+1;
	end loop;

	-- Testing for unsigned substraction
	-- Extensive testing would be from 0 up to (2**31)-1 for i and j
	report "Testing unsigned substraction";
	sub <= '1';
	i := MAX_UNSIGNED;
	j := MAX_UNSIGNED;
	
	while (i /= 0) loop 
		wait for PERIOD;
		j:= i;
		while(j /= 0) loop
			wait for PERIOD;
			a <= std_logic_vector(to_unsigned(i, 32));
			b <= std_logic_vector(to_unsigned(j, 32));

			assert to_integer(unsigned(sum)) = to_integer(unsigned(a)) - to_integer(unsigned(b))
				report "Error at a = " & integer'image(to_integer(unsigned(a))) & " and b = " & integer'image(to_integer(unsigned(b))) &
				" substraction is " & integer'image(to_integer(unsigned(sum)));
			j:= j-1;
		end loop;
		i:= i-1;
	end loop;

	-- Testing for signed addition
	-- Extensive testing would be from -(2**31) up to (2**31)-1 for i and j
	report "Testing signed addition";
	sign <= '1';
	sub <= '0';
	i:= MIN_SIGNED;
	j:= MIN_SIGNED;

	while (i /= MAX_SIGNED) loop 
		wait for PERIOD;
		j:= MIN_SIGNED;
		while(j /= MAX_SIGNED) loop
			wait for PERIOD;
			a <= std_logic_vector(to_signed(i, 32));
			b <= std_logic_vector(to_signed(j, 32));

			assert to_integer(signed(sum)) = to_integer(signed(a)) + to_integer(signed(b))
				report "Error at a = " & integer'image(to_integer(signed(a))) & " and b = " & integer'image(to_integer(signed(b))) &
				" sum is " & integer'image(to_integer(signed(sum)));
			j:= j+1;
		end loop;
		i:= i+1;
	end loop;

	-- Testing for signed substraction
	report "Testing signed substraction";
	sign <= '1';
	sub <= '1';
	i:= MIN_SIGNED;
	j:= MIN_SIGNED;

	while (i /= MAX_SIGNED) loop 
		wait for PERIOD;
		j:= MIN_SIGNED;
		while(j /= MAX_SIGNED) loop
			wait for PERIOD;
			a <= std_logic_vector(to_signed(i, 32));
			b <= std_logic_vector(to_signed(j, 32));

			assert to_integer(signed(sum)) = to_integer(signed(a)) - to_integer(signed(b))
				report "Error at a = " & integer'image(to_integer(signed(a))) & " and b = " & integer'image(to_integer(signed(b))) &
				" substraction is " & integer'image(to_integer(signed(sum)));
			j:= j+1;
		end loop;
		i:= i+1;
	end loop;

    report "<<---- Simulation Stop ---->>";
    wait until false;
  end process do_tb;	
			
end tb;