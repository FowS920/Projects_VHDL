library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.all;
use work.mini_riscv_pkg.all;

entity rv_rf_tb is
end rv_rf_tb;

architecture tb of rv_rf_tb is

	component rv_rf is
		port(
			in_clk, in_rstn : in  std_logic;
			in_we           : in  std_logic;
			in_addr_ra      : in  std_logic_vector(REG - 1 downto 0);
			out_data_ra     : out std_logic_vector(XLEN - 1 downto 0);
			in_addr_rb      : in  std_logic_vector(REG - 1 downto 0);
			out_data_rb     : out std_logic_vector(XLEN - 1 downto 0);
			in_addr_w       : in  std_logic_vector(REG - 1 downto 0);
			in_data_w       : in  std_logic_vector(XLEN - 1 downto 0)
		);
	end component rv_rf;

	constant PERIOD : time := 10 ns;

	signal clk, rstn, we            : std_logic                           := '0';
	signal addr_ra, addr_rb, addr_w : std_logic_vector(REG - 1 downto 0)  := (others => '0');
	signal data_ra, data_rb, data_w : std_logic_vector(XLEN - 1 downto 0) := (others => '0');

begin

	-- DUT
	u_rv_rf : rv_rf
		port map(
			in_clk      => clk,
			in_rstn     => rstn,
			in_we       => we,
			in_addr_ra  => addr_ra,
			out_data_ra => data_ra,
			in_addr_rb  => addr_rb,
			out_data_rb => data_rb,
			in_addr_w   => addr_w,
			in_data_w   => data_w
		);

	clk <= not clk after PERIOD / 2;

	-- Main TB process
	do_tb : process
		variable i : integer := 0;
	begin
		report "<<---- Simulation Start ---->>";
		-- Reset everything	
		rstn   <= '0';
		addr_w <= std_logic_vector(to_unsigned(1, REG)); -- Si 0, metavalue ?
		wait for PERIOD;
		rstn   <= '1';
		wait for PERIOD;

		-- Check for all data in rf to be zeros --
		report "Check for reset success";
		while (i /= 2**REG) loop
			addr_ra <= std_logic_vector(to_unsigned(i, REG));
			wait for PERIOD;
			assert to_integer(unsigned(data_ra)) = 0
			report "i's value is " & integer'image(i)
			severity WARNING;
			i       := i + 1;
		end loop;
		i := 0;

		-- Try to write in address zero to max REG --
		report "Check for write operation";
		wait for PERIOD;
		we <= '1';

		while (i /= 2**REG) loop
			addr_w <= std_logic_vector(to_unsigned(i, REG));
			data_w <= std_logic_vector(to_unsigned(i + 1, XLEN));

			wait for PERIOD;
			i := i + 1;
		end loop;
		i := 0;

		wait for PERIOD;

		-- Read address if addr 0 is writable -- 
		report "Check if addr0 is writable";
		we      <= '0';
		wait for PERIOD;
		addr_ra <= (others => '0');
		wait for PERIOD;

		assert to_integer(unsigned(data_ra)) = 0
		report "ADDR0 is writable"
		severity WARNING;
		wait for PERIOD;

		-- Read address 1 to max REG -- 
		report "Check if other addresses are writable";
		i := 1;

		while (i /= 2**REG) loop
			addr_ra <= std_logic_vector(to_unsigned(i, REG));
			wait for PERIOD;
			assert to_integer(unsigned(data_ra)) = i + 1
			report "Problem in read or write operations at " & integer'image(i)
			severity WARNING;
			i       := i + 1;
		end loop;
		i := 0;

		-- Check data_ra and data_rb when their address is equal to addr_w
		report "Check behavior when addr_ra is equal to addr_w";
		we <= '1';
		wait for PERIOD;

		addr_ra <= std_logic_vector(to_unsigned(12, REG));
		addr_rb <= std_logic_vector(to_unsigned(15, REG));
		data_w  <= std_logic_vector(to_unsigned(151, XLEN));

		wait for PERIOD;

		addr_w <= addr_ra;

		wait for PERIOD;

		assert to_integer(unsigned(data_ra)) = to_integer(unsigned(data_w))
		report "Memory is not bypassed when addr_w and addr_ra are equal"
		severity WARNING;

		wait for PERIOD;

		report "Check behavior when addr_rb is equal to addr_w";

		addr_ra <= std_logic_vector(to_unsigned(12, REG));
		addr_rb <= std_logic_vector(to_unsigned(15, REG));
		data_w  <= std_logic_vector(to_unsigned(151, XLEN));

		wait for PERIOD;

		addr_w <= addr_rb;

		wait for PERIOD;

		assert to_integer(unsigned(data_rb)) = to_integer(unsigned(data_w))
		report "Memory is not bypassed when addr_w and addr_rb are equal"
		severity WARNING;

		wait for PERIOD;

		-- Reset everything	
		rstn <= '0';
		wait for PERIOD;
		rstn <= '1';
		wait for PERIOD;

		-- Check for all data in rf to be zeros --
		report "Check for last reset success";
		while (i /= 2**REG) loop
			addr_ra <= std_logic_vector(to_unsigned(i, REG));
			wait for PERIOD;
			assert to_integer(unsigned(data_ra)) = 0
			report "Last reset didn't work at " & integer'image(i)
			severity WARNING;
			i       := i + 1;
		end loop;
		i := 0;

		report "<<---- Simulation Stop ---->>";
		wait until false;
	end process do_tb;

end tb;
