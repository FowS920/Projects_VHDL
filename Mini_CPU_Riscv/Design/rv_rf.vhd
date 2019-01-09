library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.all;
use work.mini_riscv_pkg.all;

entity rv_rf is
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
end entity;

architecture RTL of rv_rf is

	-- Determine the size of each data location
	type data_size is array (natural range <>) of std_logic_vector(XLEN - 1 downto 0);

	-- Declare the memory module (REG**2 addresses of XLEN data size)
	signal memory : data_size(2**REG - 1 downto 0);

	-- Next out_data_ra
	signal out_data_ra_p0 : std_logic_vector(XLEN - 1 downto 0);
	-- Next out_data_rb
	signal out_data_rb_p0 : std_logic_vector(XLEN - 1 downto 0);

begin

	-- Clocked process (it updates out_data_ra and out_data_rb)
	process(in_clk, in_rstn)
	begin
		if (in_rstn = '0') then
			out_data_ra <= (others => '0');
			out_data_rb <= (others => '0');
		elsif rising_edge(in_clk) then
			out_data_ra <= out_data_ra_p0;
			out_data_rb <= out_data_rb_p0;
		end if;
	end process;

	-- Determine out_data_ra_p0 and next out_data_rb_p0
	process(in_addr_ra, in_addr_rb, in_we, in_addr_w)
		-- Convert address_ra to integer
		variable address_ra_v : integer;
		-- Convert address_rb to integer
		variable address_rb_v : integer;
	begin
		address_ra_v := to_integer(unsigned(in_addr_ra));
		address_rb_v := to_integer(unsigned(in_addr_rb));

		case in_we is
			-- Memory won't be updated, do not check for matching addresses
			when '0' =>
				out_data_ra_p0 <= memory(address_ra_v);
				out_data_rb_p0 <= memory(address_rb_v);
			-- Memory will be updated, check for matching addresses
			when '1' =>
				-- Address ra is equivalent to address being written
				if (in_addr_ra = in_addr_w) then
					out_data_ra_p0 <= in_data_w;
				else
					out_data_ra_p0 <= memory(address_ra_v);
				end if;

				-- Address rb is equivalent to address being written
				if (in_addr_rb = in_addr_w) then
					out_data_rb_p0 <= in_data_w;
				else
					out_data_rb_p0 <= memory(address_rb_v);
				end if;
			-- Unstable
			when others =>
				out_data_ra_p0 <= memory(address_ra_v);
				out_data_rb_p0 <= memory(address_rb_v);
		end case;
	end process;

	-- Clocked process (it updates memory)
	process(in_clk, in_rstn)
		-- Convert address_w to integer
		variable in_addr_w_v : integer;
	begin
		in_addr_w_v := to_integer(unsigned(in_addr_w));

		if (in_rstn = '0') then
			memory <= (others => (others => '0'));
		elsif rising_edge(in_clk) then
			-- Memory not updated when write address is null
			if (in_addr_w_v = 0) then
				memory <= memory;
			-- Otherwise memory is updated when write enable is active
			elsif (in_we = '1') then
				memory(in_addr_w_v) <= in_data_w;
			-- Otherwise memory is not updated
			else
				memory <= memory;
			end if;
		end if;
	end process;

end architecture RTL;
