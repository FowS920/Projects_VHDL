library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.all;

entity rv_shifter is
	generic(
		-- Data size in bits
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
end entity rv_shifter;

architecture RTL of rv_shifter is

	constant ZERO : std_logic_vector(2**N - 1 downto 0) := (others => '0');

    signal data_to_shift : std_logic_vector(2**N - 1 downto 0);

    type data_size is array (natural range <>) of std_logic_vector(2**N - 1 downto 0);

    signal shifting_data : data_size(N - 1 downto 0);

begin

    process(in_direction, in_data)
    begin
        case in_direction is
            when '0'    =>
                data_to_shift <= in_data(2**N - 1 downto 0);
            when '1'    =>
                for i in 0 to 2**N - 1 loop
                    data_to_shift(i) <= in_data(2**N - 1 - i);
                end loop;
            when others =>
                data_to_shift <= in_data(2**N - 1 downto 0);
        end case;
    end process;
    
    process(in_shamt(0), data_to_shift)
    begin        
         case in_shamt(0) is
            when '0' =>
                shifting_data(0) <= data_to_shift;
            when '1' =>
                if (in_arith = '1') then
                    shifting_data(0) <= data_to_shift(2**N - 2 downto 0) & data_to_shift(0); --data_to_shift(2**N - 1); -- Repeat last bit (order is flipped so repeat first)
                else
                    shifting_data(0) <= data_to_shift(2**N - 2 downto 0) & ZERO(2**N - 1);
                end if;
            when others =>
                shifting_data(0) <= data_to_shift;
        end case;
    end process;
    
    gen_mul_path : for i in 1 to (N - 1) generate
        process(in_shamt(i), shifting_data(i - 1))
        begin
            case in_shamt(i) is
                when '0' =>
                    shifting_data(i) <= shifting_data(i - 1);
                when '1' =>
                    if (in_arith = '1') then
                        shifting_data(i) <= shifting_data(i-1)(2**N - 1 - 2**i downto 0) & (2**N - 1 downto 2**N - 2**i => data_to_shift(0));
                    else
                        shifting_data(i) <= shifting_data(i-1)(2**N - 1 - 2**i downto 0) & ZERO(2**N - 1 downto 2**N - 2**i);
                    end if;
                when others =>
                    shifting_data(i) <= shifting_data(i - 1);
            end case;
        end process;
    end generate;
    
    process(in_direction, shifting_data(N - 1))
    begin
        case in_direction is
            when '0'    =>
                out_data <= shifting_data(N - 1)(2**N - 1 downto 0);
            when '1'    =>
                for i in 0 to 2**N - 1 loop
                    out_data(i) <= shifting_data(N - 1)(2**N - 1 - i);
                end loop;
            when others =>
                out_data <= shifting_data(N - 1)(2**N - 1 downto 0);
        end case;
    end process;

	-- process(in_shamt, in_direction, in_arith, in_data)
	-- 	-- Convert shamt to integer
	-- 	variable shamt_v : integer;

	--	-- Esthetic signal combination
	--	variable direction_arith_v : std_logic_vector(1 downto 0);
	-- begin
	--	shamt_v := to_integer(unsigned(in_shamt));

	--	direction_arith_v := in_direction & in_arith;

	--	case shamt_v is
	--		when 0 =>
	--			out_data <= in_data;
	--		when others =>
	--			case direction_arith_v is
	--				-- Shift left by shamt_v, logical
	--				when "00"   => out_data <= in_data(2**N - 1 - shamt_v downto 0) & ZERO(shamt_v - 1 downto 0);
	--				-- Shift left by shamt_v, logical
	--				when "01"   => out_data <= in_data(2**N - 1 - shamt_v downto 0) & ZERO(shamt_v - 1 downto 0);
	--				-- Shift right by shamt_v, logical
	--				when "10"   => out_data <= ZERO(shamt_v - 1 downto 0) & in_data(2**N - 1 downto shamt_v);
	--				-- Shift right by shamt_v, arithmetic
	--				when "11"   => out_data <= in_data(shamt_v - 1 downto 0) & in_data(2**N - 1 downto shamt_v);
	--				-- Unstable
	--				when others => out_data <= in_data;
	--			end case;
	--	end case;
	-- end process;

end architecture RTL;

