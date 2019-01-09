library ieee; 
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.all;
use work.mini_riscv_pkg.all;

entity rv_alu_tb is 
end rv_alu_tb;

architecture tb of rv_alu_tb is

component rv_alu is
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
end component rv_alu;

  constant N : integer := 32;
  signal src1, src2 : std_logic_vector(N-1 downto 0);
  signal shamt : std_logic_vector(4 downto 0);
  signal arith, direction, sign : std_logic;
  signal opcode : instruction;
  signal result : std_logic_vector(N-1 downto 0);

  signal gold : unsigned(N-1 downto 0);
  signal temp : std_logic_vector(N-1 downto 0);
  constant PERIOD   : time := 10 ns;
  
begin

  -- DUT
  u_rv_alu : rv_alu
    generic map(N => N)
    port map ( 
	in_arith 	=> arith,
	in_sign 	=> sign,
	in_opcode	=> opcode,
   	in_shamt   	=> shamt,
	in_src1 	=> src1,
	in_src2		=> src2,
	out_res		=> result
	);

  -- Main TB process
do_tb : process
	variable i : integer := 0;
begin
    	report "<<---- Simulation Start ---->>";
    	report "Test Shifter"; 		-- Shifter was already tested in a separated test bench, we only test a 
					-- few combination to see if it is wired correctly
   	arith  <= '0';
	sign   <= '0';		
	opcode <= ASM_SRL; 	-- Shift Right Logical
	shamt  <= "01011"; 	-- Shift 7 bit to the right 
	src1   <= "11110000110010100101001100001111";
	src2   <= (others=>'0'); -- Doesnt care for src2 when using the shifter 	 
	
	wait for PERIOD;
	
	assert to_integer(unsigned(result)) = to_integer(unsigned(shift_right(unsigned(src1), to_integer(unsigned(shamt))))) 
		report "Error with shifter's connections"
		severity WARNING;



    	report "Test Adder";		-- Just as for the shifter, the adder was tested previously on another test
					-- bench, we only test for connections

   	arith  <= '0';		-- Addition
	sign   <= '1';		-- Signed	
	opcode <= ASM_ADD; 	-- ADDITION
	shamt  <= "00000"; 	-- Doesnt matter 
	src1   <= "00000000000000000000010000000001";
	src2   <= "00000000000000000000000001000101"; 	 

	wait for PERIOD;
	
	assert  to_integer(signed(result)) = to_integer(signed(src1)) + to_integer(signed(src2))
		report "Error with adder's connections"
		severity WARNING;

	wait for PERIOD;

    	report "Test SLT";

   	arith  <= '1';		-- Substraction
	sign   <= '1';		-- Signed	
	opcode <= ASM_SLT; 	-- Set Less Than
	shamt  <= "00000"; 	-- Doesnt matter 
	src1   <= "00000000000000001110010101001101";
	src2   <= "00000000000000110010100110101000"; -- Src2 is bigger

	wait for PERIOD;
	
	temp <= std_logic_vector(to_signed(to_integer(signed(src1)) - to_integer(signed(src2)), N));
	
	wait for PERIOD; 

	assert  temp(N-1) = result(0)
		report "Error with slt's connections when src2 is bigger than src1"
		severity WARNING;	

	wait for PERIOD;

	src1   <= "00000000000000110010100110101000"; -- Src1 is bigger
	src2   <= "00000000000000001110010101001101";

	wait for PERIOD;

	temp <= std_logic_vector(to_signed(to_integer(signed(src1)) - to_integer(signed(src2)), N));
	
	wait for PERIOD; 

	assert  temp(N-1) = result(0)
		report "Error with slt's connections when src1 is bigger than src2"
		severity WARNING;	
	
	wait for PERIOD;

    	report "Test AND";
	arith  <= '0';
	sign   <= '0';		
	opcode <= ASM_AND; 	-- AND
	shamt  <= "00000"; 	-- Doesnt matter 
	src1   <= "01110000110010100101001100001111";
	src2   <= "00101010101010101010101010101010";

	wait for PERIOD;

	assert to_integer(unsigned(result)) = to_integer(unsigned(src1 AND src2))
		report "Error with AND"
		severity WARNING; 	 

    report "Test XOR";
	arith  <= '0';
	sign   <= '0';		
	opcode <= ASM_XOR; 	-- XOR
	shamt  <= "01011"; 	-- Doesnt matter 
	src1   <= "01110000110010100101001100001111";
	src2   <= "00101010101010101010101010101010"; 	 
	
	wait for PERIOD;

	assert to_integer(unsigned(result)) = to_integer(unsigned(src1 XOR src2))
		report "Error with XOR"
		severity WARNING; 	

    report "Test OR";
	arith  <= '0';
	sign   <= '0';		
	opcode <= ASM_OR; 	-- OR
	shamt  <= "01011"; 	-- Doesnt matter 
	src1   <= "01110000110010100101001100001111";
	src2   <= "00101010101010101010101010101010"; 	
	
	wait for PERIOD;

	assert to_integer(unsigned(result)) = to_integer(unsigned(src1 OR src2))
		report "Error with OR"
		severity WARNING; 	


    report "<<---- Simulation Stop ---->>";
    wait until false;
  end process do_tb;	
			
end tb;