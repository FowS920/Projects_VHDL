library ieee; 
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.all;
use work.mini_riscv_pkg.all;

entity rv_pc_tb is 
end rv_pc_tb;

architecture tb of rv_pc_tb is

component rv_pc is
	port(
		in_clk       : in  std_logic;
		in_rstn      : in  std_logic;
		in_stall     : in  std_logic;
		in_transfert : in  std_logic;
		in_target    : in  std_logic_vector(XLEN - 1 downto 0);
		out_pc       : out std_logic_vector(XLEN - 1 downto 0)
	);
end component rv_pc;

constant N : integer := 32;
constant PERIOD   : time := 10 ns;

signal clk : std_logic := '0';
signal rstn, stall, transfert : std_logic := '0';
signal target, pc, temp : std_logic_vector(N-1 downto 0);

begin

  -- DUT
  u_rv_pc : rv_pc
    port map ( 
	    in_clk		 => clk,
	    in_rstn 	 => rstn,
	    in_stall	 => stall,
   	    in_transfert => transfert,
	    in_target 	 => target,
	    out_pc		 => pc
	);

	clk <= not clk after PERIOD / 2;

  -- Main TB process
do_tb : process
	variable i : integer := 0;

begin
    	report "<<---- Simulation Start ---->>";  	
	target <= (others=>'0');

	wait for 2*PERIOD;
	
	-- Test for holding RSTN --
	report "Test for holding RSTN";
	while (i /= 5) loop 
		wait for PERIOD;
		assert to_integer(unsigned(pc)) = 0
			report	"Rstn is not working properly"
			severity WARNING; 
		i:=i+1;
	end loop;

	wait for PERIOD;
	i:=0;
	rstn <= '1';
	
	-- Test for normal operation --
	report "Test for normal operation";
	while (i /= 5) loop 
		wait for PERIOD;
		assert to_integer(unsigned(pc)) = (i+1)*4
			report	"Problem in normal operation"
			severity WARNING; 
		i:=i+1;
	end loop;
	i:=0;

	wait for PERIOD;

	-- Test for target --
	report "Test for target tranfert";

	target <= "00000000000000000110000000000000"; -- Set target
	transfert <= '1';

	wait for PERIOD;

	transfert <= '0';

	assert to_integer(unsigned(pc)) = to_integer(unsigned(target))
		report	"Problem in target transfert"
		severity WARNING; 
	
	-- Return to normal operation --
	report "Test for return to normal operation";

	while (i /= 5) loop 
		wait for PERIOD;
		assert to_integer(unsigned(pc)) = (i+1)*4+to_integer(unsigned(target))
			report	"Problem in normal operation after target transfert"
			severity WARNING; 
		i:=i+1;
	end loop;
	i:=0;

	wait for PERIOD;

	-- Test for stall --
	report "Test for stall";
	stall <= '1';
	temp <= pc;

	while (i /= 5) loop 
		wait for PERIOD;
		assert to_integer(unsigned(pc)) = to_integer(unsigned(temp))
			report	"Problem in stall"
			severity WARNING; 
		i:=i+1;
	end loop;
	i:=0;

	stall <= '0';

	wait for 5*PERIOD; -- keep running pc

	-- Final RSTN test --
	report "Test for final RSTN";
	rstn <= '0';

	wait for PERIOD;
	 
	assert to_integer(unsigned(pc)) = 0
		report "Problem with final reset"
		severity WARNING;
	
    	report "<<---- Simulation Stop ---->>";
    	wait until false;
end process do_tb;	
			
end tb;
