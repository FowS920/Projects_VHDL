library ieee; 
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;


--library std;
--use std.textio.all;                                                      
--use std.env.all;

library work;
use work.all;
use work.mini_riscv_pkg.all;

entity rv_shifter_tb is 
end rv_shifter_tb;

architecture tb of rv_shifter_tb is


component rv_shifter is
	generic(
		-- Data size (2**N)
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

  constant N : integer := 4;
  signal data : std_logic_vector((2**N)-1 downto 0);
  signal shamt : std_logic_vector(N-1 downto 0);
  signal arith, direction : std_logic;
  signal result : std_logic_vector((2**N)-1 downto 0);

  signal gold : unsigned(2**N-1 downto 0);
  constant PERIOD   : time := 10 ns;
  
begin

  -- DUT
  u_rv_shifter : rv_shifter
    generic map(N => N)
    port map ( 
	in_data 	=> data,
   	in_shamt   	=> shamt,
	in_arith 	=> arith,
	in_direction  	=> direction,
      	out_data	=> result
	);

  -- Main TB process
  do_tb : process
    variable i : integer := 0;
begin
    report "<<---- Simulation Start ---->>";
    data <= "1111000011001010";

    -- Test for Shift Left Logical
    report "<<---- Test for Left Shift Logical ---->>";
    direction <= '0';
    arith <= '0';
    shamt <= (others=>'0');
    i := 0; 
    
    while (i /= 2**N) loop 	-- Tetst from 0 to 15 because VHDL does work well with integers above 2**31 (integers are signed). Asserting was harder because std_logic_vector used as unsigned can't overflow integer type
	wait for PERIOD;	
	shamt <= std_logic_vector(to_unsigned(i, N));
		
	wait for PERIOD;
	assert to_integer(unsigned(result)) = to_integer(unsigned(shift_left(unsigned(data), i)))
		report "Error at SLL shamt = " & integer'image(i)
		severity WARNING;
	i := i+1;
    end loop;


    -- Test for Shift Right Logical
    report "<<---- Shift Right Logical---->>";
    direction <= '1';
    arith <= '0';
    shamt <= (others=>'0');
    i := 0; 
    wait for PERIOD;

    while (i /= 2**N) loop 	
	wait for PERIOD;
	shamt <= std_logic_vector(to_unsigned(i, N));
		
	wait for PERIOD;
	assert to_integer(unsigned(result)) = to_integer(unsigned(shift_right(unsigned(data), i)))
		report "Error at SRL with shamt = " & integer'image(i)
		severity WARNING;
	i := i+1;
    end loop;

    -- Test for Shift Right Arithmetic with MSB = 1 
    report "<<---- Shift Right Arithmetic with MSB = 1 ---->>";
    direction <= '1';
    arith <= '1';
    shamt <= (others=>'0');
    i := 0; 
    wait for PERIOD;

    while (i /= 2**N) loop 	
	wait for PERIOD;
	shamt <= std_logic_vector(to_unsigned(i, N));
	gold <= unsigned(shift_right(signed(data), i));
	wait for PERIOD;
	assert to_integer(unsigned(result)) = to_integer(unsigned(shift_right(signed(data), i)))
		report "Error at SRA (MSB=1) with shamt = " & integer'image(i)
		severity WARNING;
	i := i+1;
    end loop;

    -- Test for Shift Right Arithmetic with MSB = 0
    report "<<---- Shift Right Arithmetic with MSB = 0 ---->>";
    direction <= '1';
    arith <= '1';
    shamt <= (others=>'0');
    data <= "0101001100001111";
    i := 0; 
    wait for PERIOD;

    while (i /= 2**N) loop 	
	wait for PERIOD;
	shamt <= std_logic_vector(to_unsigned(i, N));
	gold <= unsigned(shift_right(signed(data), i));
	wait for PERIOD;
	assert to_integer(unsigned(result)) = to_integer(unsigned(shift_right(signed(data), i)))
		report "Error at SRA (MSB=0) with shamt = " & integer'image(i)
		severity WARNING;
	i := i+1;
    end loop;
	
    report "<<---- Simulation Stop ---->>";
    wait until false;
  end process do_tb;	
			
end tb;