library ieee; 
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

--library std;
--use std.textio.all;                                                      
--use std.env.all;

library work;
use work.all;
use work.mini_riscv_pkg.all;

entity rv_hadd_tb is 
end rv_hadd_tb;

architecture tb of rv_hadd_tb is

  component rv_hadd is
    port( 	in_a      : in  std_logic;
		in_b      : in  std_logic;
		out_sum   : out std_logic;
		out_carry : out std_logic);
  end component;

  signal a, b : std_logic;
  signal sum, carry : std_logic;	

  constant PERIOD   : time := 10 ns;
  
begin

  -- DUT
  u_rv_hadd : rv_hadd
    port map ( 
	in_a  	=> a,
   	in_b   	=> b,
      	out_sum	=> sum,     
      	out_carry  => carry
	);

  -- Main TB process
  do_tb : process
  begin
    report "<<---- Simulation Start ---->>";
	a <= '0';
	b <= '0';
    wait for PERIOD;
    assert sum = '0'
	report "Sum incorrect"
	severity Warning;
    assert carry = '0'
	report "Carry incorrect"
	severity Warning;

	a <= '1';
	b <= '0';
    wait for PERIOD;
    assert sum = '1'
	report "Sum incorrect"
	severity Warning;
    assert carry = '0'
	report "Carry incorrect"
	severity Warning;

	a <= '0';
	b <= '1';
    wait for PERIOD;
    assert sum = '1'
	report "Sum incorrect"
	severity Warning;
    assert carry = '0'
	report "Carry incorrect"
	severity Warning;

	a <= '1';
	b <= '1';
    wait for PERIOD;
    assert sum = '0'
	report "Sum incorrect"
	severity Warning;
    assert carry = '1'
	report "Carry incorrect"
	severity Warning;
    
    report "<<---- Simulation Stop ---->>";
    wait until false;
  end process do_tb;	
			
end tb;