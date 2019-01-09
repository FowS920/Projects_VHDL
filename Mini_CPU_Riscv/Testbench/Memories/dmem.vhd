-------------------------------------------------------------------------------
-- Project    : ELE8304 : Circuits intégrés à très grande échelle 
-- Description: Conception d'un microprocesseur mini-riscv
-------------------------------------------------------------------------------
-- File       : dmem.vhd
-- Author     : Mickael Fiorentino  <mickael.fiorentino@polymtl.ca>
-- Lab        : grm@polymtl
-- Created    : 2017-08-01
-- Last update: 2018-08-30
-------------------------------------------------------------------------------
-- Description: Data Memory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dmem is
	generic(
		ADDR_WIDTH : positive := 10;
		DATA_WIDTH : positive := 32);
	port(
		in_clk   : in  std_logic;
		in_we    : in  std_logic;
		in_addr  : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
		in_write : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		out_read : out std_logic_vector(DATA_WIDTH - 1 downto 0));
end entity dmem;

architecture beh of dmem is

type dmem_t is array (0 to 2**ADDR_WIDTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);

type protected_mem is protected
    impure function get ( constant idx : in natural) return std_logic_vector;
    procedure set ( idx: natural; new_value : std_logic_vector(DATA_WIDTH-1 downto 0));
end protected protected_mem;

type protected_mem is protected body
  
    variable mem : dmem_t := (others=>(others=>'0'));

    impure function get (constant idx : in natural) return std_logic_vector is      
    begin
      return mem(idx);
    end function get;
   
    procedure set ( idx: natural; new_value : std_logic_vector(DATA_WIDTH-1 downto 0) ) is
    begin
      mem(idx) := new_value;
    end procedure set;
      
  end protected body protected_mem;

  shared variable dmem : protected_mem;
  signal addr_rd : std_logic_vector(ADDR_WIDTH-1 downto 0);
  
begin

  do_write_dmem: process(in_clk)
    variable iaddr : natural;
  begin    
    if in_clk'event and in_clk = '1' then
      if in_we = '1' then
        iaddr := to_integer(unsigned(in_addr));
        dmem.set(iaddr, in_write);
      end if;
      addr_rd <= in_addr;
    end if;    
  end process do_write_dmem;

  out_read <= dmem.get(to_integer(unsigned(addr_rd)));
  
end architecture beh;
