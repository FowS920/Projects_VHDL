library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.all;
use work.mini_riscv_pkg.all;

library std;
use std.textio.all;
use std.env.all;

entity rv_core_tb is
end rv_core_tb;

architecture testbench of rv_core_tb is

	constant CLK_PERIOD : time := 10 ns;

	signal in_clk  : std_logic := '0';
	signal in_rstn : std_logic := '0';

	signal in_imem_read : std_logic_vector(31 downto 0);
	signal in_dmem_read : std_logic_vector(31 downto 0);
	signal in_imem_addr : std_logic_vector(9 downto 0);

	signal out_imem_addr  : std_logic_vector(9 downto 0);
	signal out_dmem_we    : std_logic;
	signal out_dmem_addr  : std_logic_vector(9 downto 0);
	signal out_dmem_write : std_logic_vector(31 downto 0);

begin

	in_imem_addr <= "00" & out_imem_addr(9 downto 2);

	xrv_core : mini_riscv_pkg.rv_core
		port map(
			in_clk         => in_clk,
			in_rstn        => in_rstn,
			in_imem_read   => in_imem_read,
			out_imem_addr  => out_imem_addr,
			in_dmem_read   => in_dmem_read,
			out_dmem_we    => out_dmem_we,
			out_dmem_addr  => out_dmem_addr,
			out_dmem_write => out_dmem_write
		);

	xrv_dmem : mini_riscv_pkg.dmem
		generic map(
			ADDR_WIDTH => 10,
			DATA_WIDTH => 32
		)
		port map(
			in_clk   => in_clk,
			in_we    => out_dmem_we,
			in_addr  => out_dmem_addr,
			in_write => out_dmem_write,
			out_read => in_dmem_read
		);

	xrv_imem : mini_riscv_pkg.imem
		generic map(
			INIT_FILE  => "../ELE8304/FIBO/init.hex",
			ADDR_WIDTH => 10,
			DATA_WIDTH => 32
		)
		port map(
			in_addr  => in_imem_addr,
			out_read => in_imem_read
		);

	in_clk <= not in_clk after CLK_PERIOD / 2;

	proc_testbech : process
		variable i : integer := 0;
		variable j : integer := 1;
		variable k : integer := 1;
	begin
		in_rstn <= '0';

		wait for 20 ns;

		in_rstn <= '1';

		report "<<---- Simulation Start ---->>";

		while i < 6765 loop

			k := i + j;
			i := j;
			j := k;

			wait until rising_edge(out_dmem_we);

			assert to_integer(unsigned(out_dmem_write)) = i report "Problem in Fibo" & integer'image(i) severity WARNING;

		end loop;

		report "<<----- Simulation End ----->>";

		wait until false;

		--stop;

	end process proc_testbech;

end architecture testbench;

