-------------------------------------------------------------------------------
-- Project    : ELE8304 : Circuits intégrés à très grande échelle 
-- Description: Conception d'un microprocesseur mini-riscv
-------------------------------------------------------------------------------
-- File       : imem.vhd
-- Author     : Mickael Fiorentino  <mickael.fiorentino@polymtl.ca>
-- Lab        : grm@polymtl
-- Created    : 2017-08-01
-- Last update: 2018-10-04
-------------------------------------------------------------------------------
-- Description: Instruction Memory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity imem is
	generic(
		INIT_FILE  : string   := "../asm/init.hex";
		ADDR_WIDTH : positive := 10;
		DATA_WIDTH : positive := 32);
	port(
		in_addr  : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
		out_read : out std_logic_vector(DATA_WIDTH - 1 downto 0));
end entity imem;

architecture beh of imem is

	type imem_t is array (0 to 2**ADDR_WIDTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);

	impure function init_imem(constant in_file : in string) return imem_t is

		file imem_file       : text open read_mode is in_file;
		variable read_line   : line    := null;
		variable read_status : boolean;
		variable next_addr   : natural := 0;
		variable mem         : imem_t  := (others => (others => '0'));

	begin

		while not endfile(imem_file) loop
			-- Read next line
			readline(imem_file, read_line);
			hread(read_line, mem(next_addr), read_status);

			-- Check read status
			assert read_status = true
			report "init_mem: error reading data at address "
        	& to_string(next_addr)
        	& " in file " & in_file
			severity error;

			-- Check address range
			assert next_addr < 2**ADDR_WIDTH - 1
			report "init_mem: " & to_string(next_addr)
        	& " out of range [" & to_string(0)
        	& " ; " & to_string(2**ADDR_WIDTH-1) & "]"
			severity error;

			next_addr := next_addr + 1;
		end loop;

		return mem;

	end function init_imem;

	signal imem : imem_t := init_imem(INIT_FILE);

begin

	out_read <= imem(to_integer(unsigned(in_addr)));

end architecture beh;
