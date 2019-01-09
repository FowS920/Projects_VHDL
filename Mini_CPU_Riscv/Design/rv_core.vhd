library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.all;
use work.mini_riscv_pkg.all;

entity rv_core is
	port(
		in_clk         : in  std_logic;
		in_rstn        : in  std_logic;
		in_imem_read   : in  std_logic_vector(31 downto 0);
		out_imem_addr  : out std_logic_vector(9 downto 0);
		in_dmem_read   : in  std_logic_vector(31 downto 0);
		out_dmem_we    : out std_logic;
		out_dmem_addr  : out std_logic_vector(9 downto 0);
		out_dmem_write : out std_logic_vector(31 downto 0)
	);
end entity rv_core;

architecture RTL of rv_core is

	-- Register file TYPE used to interact with register file
	type register_file is record
		we      : std_logic;
		addr_ra : std_logic_vector(REG - 1 downto 0);
		data_ra : std_logic_vector(XLEN - 1 downto 0);
		addr_rb : std_logic_vector(REG - 1 downto 0);
		data_rb : std_logic_vector(XLEN - 1 downto 0);
		addr_w  : std_logic_vector(REG - 1 downto 0);
		data_w  : std_logic_vector(XLEN - 1 downto 0);
	end record register_file;

	signal reg_file : register_file;

	-- Program counter TYPE used to interact with program counter
	type program_counter is record
		stall     : std_logic;
		transfert : std_logic;
		target    : std_logic_vector(XLEN - 1 downto 0);
		pc        : std_logic_vector(XLEN - 1 downto 0);
	end record program_counter;

	signal prog_cnt : program_counter;

	-- Instruction Fecth (IF) to Instruction Decode (ID)
	type decode_input is record
		imem_read : std_logic_vector(31 downto 0);
		flush     : std_logic;
		pc_carry  : std_logic_vector(XLEN - 1 downto 0);
	end record decode_input;

	signal decode_in_p0 : decode_input;
	signal decode_in    : decode_input;

	-- Instruction Decode (ID) to Execute (EX)
	type execute_input is record
		decoded_instruction : instruction;
		is_imm              : std_logic; -- registre
		imm_val             : std_logic_vector(31 downto 0);
		shamt               : std_logic_vector(4 downto 0);
		pc_carry            : std_logic_vector(XLEN - 1 downto 0);
		rd_addr             : std_logic_vector(REG - 1 downto 0);
		addr_ra             : std_logic_vector(REG - 1 downto 0);
		addr_rb             : std_logic_vector(REG - 1 downto 0);
	end record execute_input;

	signal execute_in_p0 : execute_input;
	signal execute_in    : execute_input;

	signal alu_in_src1 : std_logic_vector(XLEN - 1 downto 0);
	signal alu_in_src2 : std_logic_vector(XLEN - 1 downto 0);

	signal alu_result       : std_logic_vector(XLEN - 1 downto 0);
	signal execute_in_arith : std_logic; -- Devrait etre registre ?
	signal alu_signed       : std_logic;
	signal ex_adder_out     : std_logic_vector(32 downto 0);

	-- Execute (EX) to Memory (ME)
	type memory_input is record
		decoded_instruction : instruction;
		alu_result          : std_logic_vector(XLEN - 1 downto 0);
		store_data          : std_logic_vector(31 downto 0);
		rd_addr             : std_logic_vector(REG - 1 downto 0);
	end record memory_input;

	signal is_equal     : std_logic;
	signal memory_in_p0 : memory_input;
	signal memory_in    : memory_input;

	-- Memory (ME) to Write_Back (WB)
	type write_back_input is record
		decoded_instruction : instruction;
		alu_result          : std_logic_vector(XLEN - 1 downto 0);
		rd_addr             : std_logic_vector(REG - 1 downto 0);
	end record write_back_input;

	signal write_back_in_p0 : write_back_input;
	signal write_back_in    : write_back_input;

begin

	-- Instantiate register file
	xrv_rf : work.mini_riscv_pkg.rv_rf
		port map(
			in_clk      => in_clk,
			in_rstn     => in_rstn,
			in_we       => reg_file.we,
			in_addr_ra  => reg_file.addr_ra,
			out_data_ra => reg_file.data_ra,
			in_addr_rb  => reg_file.addr_rb,
			out_data_rb => reg_file.data_rb,
			in_addr_w   => reg_file.addr_w,
			in_data_w   => reg_file.data_w
		);

	-- Instantiate program counter
	xrv_pc : work.mini_riscv_pkg.rv_pc
		generic map(
			RESET_VECTOR => 16#00000000#
		)
		port map(
			in_clk       => in_clk,
			in_rstn      => in_rstn,
			in_stall     => prog_cnt.stall,
			in_transfert => prog_cnt.transfert,
			in_target    => prog_cnt.target,
			out_pc       => prog_cnt.pc
		);

	-- Instantiate exectute's ALU
	xrv_alu : work.mini_riscv_pkg.rv_alu
		generic map(
			N => ALUOP_WIDTH
		)
		port map(
			in_arith  => execute_in_arith, -- A verifier
			in_sign   => alu_signed,
			in_opcode => execute_in.decoded_instruction,
			in_shamt  => execute_in.shamt,
			in_src1   => alu_in_src1,
			in_src2   => alu_in_src2,
			out_res   => alu_result
		);

	-- Instantiate execute's ADDER
	xrv_adder : work.mini_riscv_pkg.rv_adder
		generic map(N => 32)
		port map(
			in_a    => execute_in.pc_carry,
			in_b    => execute_in.imm_val,
			in_sign => '1',             -- Toujours signe car offset adresse
			in_sub  => '0',             -- Toujours une addition
			out_sum => ex_adder_out);

	-- Instruction Fetch
	process(prog_cnt.pc, in_imem_read)
	begin
		out_imem_addr          <= prog_cnt.pc(9 downto 0);
		decode_in_p0.imem_read <= in_imem_read; -- Mettre le contenu de la memoire dans l'entree du registre
		decode_in_p0.pc_carry  <= prog_cnt.pc;
	end process;

	-- Clocked process for IF to ID
	process(in_clk, in_rstn)
	begin
		if (in_rstn = '0') then
			decode_in.imem_read <= (others => '0');
			decode_in.flush     <= '0';
			decode_in.pc_carry  <= (others => '0');
		elsif rising_edge(in_clk) then
			if (prog_cnt.stall = '1') then
				decode_in <= decode_in;
			else
				decode_in <= decode_in_p0;
			end if;
		end if;
	end process;

	-- Instruction Decode
	process(prog_cnt.stall, decode_in)
		-- Esthetic signal combination
		variable stall_flush_v : std_logic_vector(1 downto 0);
	begin
		stall_flush_v := prog_cnt.stall & decode_in.flush; -- Concatener le stall et flush

		-- Defaults
		execute_in_p0.is_imm  <= '0';
		execute_in_p0.imm_val <= (others => '0');
		execute_in_p0.shamt   <= (others => '0');

		execute_in_p0.decoded_instruction <= ASM_NOP; -- p0 is signal sent to the register NECESSAIRE AVEC LE CASE ?

		reg_file.addr_ra <= decode_in.imem_read(19 downto 15);
		reg_file.addr_rb <= decode_in.imem_read(24 downto 20);

		execute_in_p0.addr_ra <= decode_in.imem_read(19 downto 15);
		execute_in_p0.addr_rb <= decode_in.imem_read(24 downto 20);

		execute_in_p0.pc_carry <= decode_in.pc_carry;
		execute_in_p0.rd_addr  <= decode_in.imem_read(11 downto 7);

		case stall_flush_v is
			-- Decode current operation
			when "00" =>
				execute_in_p0.is_imm <= '1';

				case decode_in.imem_read(6 downto 0) is
					when "0110111" =>
						execute_in_p0.decoded_instruction <= ASM_LUI;
						execute_in_p0.imm_val             <= (decode_in.imem_read(31 downto 12) & (11 downto 0 => '0')); -- Voir U-IMM
					when "1101111" =>
						execute_in_p0.decoded_instruction <= ASM_JAL;
						execute_in_p0.imm_val             <= (31 downto 20 => decode_in.imem_read(31)) & decode_in.imem_read(19 downto 12) & decode_in.imem_read(20) & decode_in.imem_read(30 downto 21) & '0'; -- Voir J-IMM
					when "1100111" =>
						case decode_in.imem_read(14 downto 12) is
							when "000" =>
								execute_in_p0.decoded_instruction <= ASM_JALR;
								execute_in_p0.imm_val             <= ((31 downto 12 => decode_in.imem_read(31)) & decode_in.imem_read(31 downto 20)); -- Voir I-IMM
							when others =>
								execute_in_p0.decoded_instruction <= ASM_NOP;
								execute_in_p0.imm_val             <= ((31 downto 0 => '0'));
						end case;
					when "1100011" =>
						case decode_in.imem_read(14 downto 12) is
							when "000" =>
								execute_in_p0.decoded_instruction <= ASM_BEQ;
								execute_in_p0.imm_val             <= (31 downto 12 => decode_in.imem_read(31)) & decode_in.imem_read(7) & decode_in.imem_read(30 downto 25) & decode_in.imem_read(11 downto 8) & '0'; -- Voir B-IMM
							when others =>
								execute_in_p0.decoded_instruction <= ASM_NOP;
								execute_in_p0.imm_val             <= ((31 downto 0 => '0'));
						end case;
					when "0000011" =>
						case decode_in.imem_read(14 downto 12) is
							when "010" =>
								execute_in_p0.decoded_instruction <= ASM_LW;
								execute_in_p0.imm_val             <= ((31 downto 12 => decode_in.imem_read(31)) & decode_in.imem_read(31 downto 20)); -- Voir I-IMM
							when others =>
								execute_in_p0.decoded_instruction <= ASM_NOP;
								execute_in_p0.imm_val             <= ((31 downto 0 => '0'));
						end case;
					when "0100011" =>
						case decode_in.imem_read(14 downto 12) is
							when "010" =>
								execute_in_p0.decoded_instruction <= ASM_SW;
								execute_in_p0.imm_val             <= (31 downto 12 => decode_in.imem_read(31)) & decode_in.imem_read(31 downto 25) & decode_in.imem_read(11 downto 7); -- Voir S-IMM
							when others =>
								execute_in_p0.decoded_instruction <= ASM_NOP;
								execute_in_p0.imm_val             <= ((31 downto 0 => '0'));
						end case;
					when "0010011" =>
						execute_in_p0.is_imm <= '1';

						case decode_in.imem_read(14 downto 12) is
							when "000" =>
								execute_in_p0.decoded_instruction <= ASM_ADDI;
								execute_in_p0.imm_val             <= ((31 downto 12 => decode_in.imem_read(31)) & decode_in.imem_read(31 downto 20)); -- Voir I-IMM
							when "010" =>
								execute_in_p0.decoded_instruction <= ASM_SLTI;
								execute_in_p0.imm_val             <= ((31 downto 12 => decode_in.imem_read(31)) & decode_in.imem_read(31 downto 20)); -- Voir I-IMM
							when "011" =>
								execute_in_p0.decoded_instruction <= ASM_SLTIU;
								execute_in_p0.imm_val             <= ((31 downto 12 => decode_in.imem_read(31)) & decode_in.imem_read(31 downto 20)); -- Voir I-IMM
							when "100" =>
								execute_in_p0.decoded_instruction <= ASM_XORI;
								execute_in_p0.imm_val             <= ((31 downto 12 => decode_in.imem_read(31)) & decode_in.imem_read(31 downto 20)); -- Voir I-IMM
							when "110" =>
								execute_in_p0.decoded_instruction <= ASM_ORI;
								execute_in_p0.imm_val             <= ((31 downto 12 => decode_in.imem_read(31)) & decode_in.imem_read(31 downto 20)); -- Voir I-IMM
							when "111" =>
								execute_in_p0.decoded_instruction <= ASM_ANDI;
								execute_in_p0.imm_val             <= ((31 downto 12 => decode_in.imem_read(31)) & decode_in.imem_read(31 downto 20)); -- Voir I-IMM
							when "001" =>
								case decode_in.imem_read(31 downto 25) is
									when "0000000" =>
										execute_in_p0.decoded_instruction <= ASM_SLLI;
										execute_in_p0.imm_val             <= ((31 downto 0 => '0')); -- A mod
										execute_in_p0.shamt               <= decode_in.imem_read(24 downto 20);
									when others =>
										execute_in_p0.decoded_instruction <= ASM_NOP;
										execute_in_p0.imm_val             <= ((31 downto 0 => '0'));
								end case;
							when "101" =>
								case decode_in.imem_read(31 downto 25) is
									when "0000000" =>
										execute_in_p0.decoded_instruction <= ASM_SRLI;
										execute_in_p0.imm_val             <= ((31 downto 0 => '0'));
										execute_in_p0.shamt               <= decode_in.imem_read(24 downto 20);
									when "0100000" =>
										execute_in_p0.decoded_instruction <= ASM_SRAI;
										execute_in_p0.imm_val             <= ((31 downto 6 => '0') & '1' & (4 downto 0 => '0'));
										execute_in_p0.shamt               <= decode_in.imem_read(24 downto 20);
									when others =>
										execute_in_p0.decoded_instruction <= ASM_NOP;
										execute_in_p0.imm_val             <= ((31 downto 0 => '0'));
								end case;
							when others =>
								execute_in_p0.decoded_instruction <= ASM_NOP;
								execute_in_p0.imm_val             <= ((31 downto 0 => '0'));
						end case;
					when "0110011" =>
						execute_in_p0.is_imm  <= '0';
						execute_in_p0.imm_val <= ((31 downto 0 => '0'));

						case decode_in.imem_read(14 downto 12) is
							when "000" =>
								case decode_in.imem_read(31 downto 25) is
									when "0000000" => execute_in_p0.decoded_instruction <= ASM_ADD;
									when "0100000" => execute_in_p0.decoded_instruction <= ASM_SUB;
									when others    => execute_in_p0.decoded_instruction <= ASM_NOP;
								end case;
							when "001" =>
								case decode_in.imem_read(31 downto 25) is
									when "0000000" =>
										execute_in_p0.decoded_instruction <= ASM_SLL;
										execute_in_p0.shamt               <= decode_in.imem_read(24 downto 20);
									when others => execute_in_p0.decoded_instruction <= ASM_NOP;
								end case;
							when "010" =>
								case decode_in.imem_read(31 downto 25) is
									when "0000000" => execute_in_p0.decoded_instruction <= ASM_SLT;
									when others    => execute_in_p0.decoded_instruction <= ASM_NOP;
								end case;
							when "011" =>
								case decode_in.imem_read(31 downto 25) is
									when "0000000" => execute_in_p0.decoded_instruction <= ASM_SLTU;
									when others    => execute_in_p0.decoded_instruction <= ASM_NOP;
								end case;
							when "100" =>
								case decode_in.imem_read(31 downto 25) is
									when "0000000" => execute_in_p0.decoded_instruction <= ASM_XOR;
									when others    => execute_in_p0.decoded_instruction <= ASM_NOP;
								end case;
							when "101" =>
								case decode_in.imem_read(31 downto 25) is
									when "0000000" =>
										execute_in_p0.decoded_instruction <= ASM_SRL;
										execute_in_p0.shamt               <= decode_in.imem_read(24 downto 20);
									when "0100000" =>
										execute_in_p0.decoded_instruction <= ASM_SRA;
										execute_in_p0.shamt               <= decode_in.imem_read(24 downto 20);
									when others => execute_in_p0.decoded_instruction <= ASM_NOP;
								end case;
							when "110" =>
								case decode_in.imem_read(31 downto 25) is
									when "0000000" => execute_in_p0.decoded_instruction <= ASM_OR;
									when others    => execute_in_p0.decoded_instruction <= ASM_NOP;
								end case;
							when "111" =>
								case decode_in.imem_read(31 downto 25) is
									when "0000000" => execute_in_p0.decoded_instruction <= ASM_AND;
									when others    => execute_in_p0.decoded_instruction <= ASM_NOP;
								end case;
							when others => execute_in_p0.decoded_instruction <= ASM_NOP;
						end case;
					when others =>
						execute_in_p0.decoded_instruction <= ASM_NOP;
						execute_in_p0.is_imm              <= '0';
				end case;
			-- Flush current operation
			when "01" =>
				execute_in_p0.decoded_instruction <= ASM_NOP;

				reg_file.addr_ra <= (others => '0');
				reg_file.addr_rb <= (others => '0');
			-- Stall current operation
			when "10" =>
				execute_in_p0.decoded_instruction <= ASM_NOP;

				reg_file.addr_ra <= (others => '0');
				reg_file.addr_rb <= (others => '0');
			-- Flush / Stall current operation
			when "11" =>
				execute_in_p0.decoded_instruction <= ASM_NOP;

				reg_file.addr_ra <= (others => '0');
				reg_file.addr_rb <= (others => '0');
			-- Unexpected
			when others =>
				execute_in_p0.decoded_instruction <= ASM_NOP;

				reg_file.addr_ra <= (others => '0');
				reg_file.addr_rb <= (others => '0');
		end case;
	end process;

	-- Clocked process for ID to EX
	process(in_clk, in_rstn)
	begin
		if (in_rstn = '0') then
			execute_in.is_imm  <= '0';
			execute_in.imm_val <= (others => '0');
			execute_in.shamt   <= (others => '0');

			execute_in.decoded_instruction <= ASM_NOP;

			execute_in.pc_carry <= (others => '0');
			execute_in.rd_addr  <= (others => '0');

			execute_in.addr_ra <= (others => '0');
			execute_in.addr_rb <= (others => '0');
		elsif rising_edge(in_clk) then
			execute_in <= execute_in_p0;

			execute_in.is_imm  <= execute_in_p0.is_imm;
			execute_in.imm_val <= execute_in_p0.imm_val;
			execute_in.shamt   <= execute_in_p0.shamt;

			if (decode_in_p0.flush = '1') then
				execute_in.decoded_instruction <= ASM_NOP;
			else
				execute_in.decoded_instruction <= execute_in_p0.decoded_instruction;
			end if;

			execute_in.pc_carry <= execute_in_p0.pc_carry;
			execute_in.rd_addr  <= execute_in_p0.rd_addr;

			execute_in.addr_ra <= execute_in_p0.addr_ra;
			execute_in.addr_rb <= execute_in_p0.addr_rb;
		end if;
	end process;

	-- Execute's ASM_BEQ
	process(execute_in.addr_rb, memory_in.rd_addr, alu_in_src1, memory_in.alu_result, write_back_in.rd_addr, write_back_in.alu_result, reg_file.data_rb)
	begin
		if (execute_in.addr_rb = memory_in.rd_addr) then
			if (alu_in_src1 = memory_in.alu_result) then
				is_equal <= '1';
			else
				is_equal <= '0';
			end if;
		elsif (execute_in.addr_rb = write_back_in.rd_addr) then
			if (alu_in_src1 = write_back_in.alu_result) then
				is_equal <= '1';
			else
				is_equal <= '0';
			end if;
		else
			if (alu_in_src1 = reg_file.data_rb) then
				is_equal <= '1';
			else
				is_equal <= '0';
			end if;
		end if;
	end process;

	-- Execute
	process(execute_in.decoded_instruction, execute_in.rd_addr, ex_adder_out, alu_result, is_equal)
	begin
		-- Defaults (TODO)

		memory_in_p0.decoded_instruction <= execute_in.decoded_instruction;

		-- memory_in_p0.alu_result set in execute's alu instantiation
		-- in_arith is taken care of next to alu's instantiation for shift, substraction and set less than operations

		-- Make sure ASM_NOP ASM_BEQ and ASM_SW rd_addr is 0 to avoid forwarding errors
		case execute_in.decoded_instruction is
			when ASM_NOP | ASM_BEQ | ASM_SW => memory_in_p0.rd_addr <= (others => '0');
			when others                     => memory_in_p0.rd_addr <= execute_in.rd_addr;
		end case;

		-- Dans les cas ou ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
		-- ADD, SUB, SLT, SLTU, XOR, SLL, SRL, SRA, OR et AND, les settings sont deja tous envoyes a l'ALU

		case execute_in.decoded_instruction is
			when ASM_LUI =>
				prog_cnt.transfert <= '0'; -- Load Upper Immediate
				prog_cnt.target    <= (others => '0');
				prog_cnt.stall     <= '0';
			when ASM_JAL =>
				prog_cnt.transfert <= '1'; -- Saut relatif a la valeur du compteur
				prog_cnt.target    <= ex_adder_out(31 downto 0);
				prog_cnt.stall     <= '0';
			when ASM_JALR =>
				prog_cnt.transfert <= '1'; -- Saut indep de la valeur courante du compteur
				prog_cnt.target    <= alu_result(31 downto 0);
				prog_cnt.stall     <= '0';
			when ASM_BEQ =>
				prog_cnt.transfert <= is_equal; -- Branch on equal, voir le if plus haut
				prog_cnt.target    <= ex_adder_out(31 downto 0);
				prog_cnt.stall     <= '0';
			when ASM_LW =>
				prog_cnt.transfert <= '0';
				prog_cnt.target    <= (others => '0');
				prog_cnt.stall     <= '1';
			when ASM_SW =>
				prog_cnt.transfert <= '0';
				prog_cnt.target    <= (others => '0');
				prog_cnt.stall     <= '0';
			when ASM_NOP =>
				prog_cnt.transfert <= '0';
				prog_cnt.target    <= (others => '0');
				prog_cnt.stall     <= '0';
			when others =>
				prog_cnt.transfert <= '0';
				prog_cnt.target    <= (others => '0');
				prog_cnt.stall     <= '0';
		end case;

		case execute_in.decoded_instruction is
			when ASM_LUI  => decode_in_p0.flush <= '0';
			when ASM_JAL  => decode_in_p0.flush <= '1';
			when ASM_JALR => decode_in_p0.flush <= '1';
			when ASM_BEQ  => decode_in_p0.flush <= is_equal;
			when others   => decode_in_p0.flush <= '0';
		end case;
	end process;

	-- Execute's addr_ra forwarding logic
	process(execute_in.addr_ra, memory_in.rd_addr, memory_in.alu_result, write_back_in.rd_addr, reg_file.data_w, reg_file.data_ra)
	begin
		if (execute_in.addr_ra = memory_in.rd_addr) then
			alu_in_src1 <= memory_in.alu_result;
		elsif (execute_in.addr_ra = write_back_in.rd_addr) then
			alu_in_src1 <= reg_file.data_w;
		else
			alu_in_src1 <= reg_file.data_ra;
		end if;
	end process;

	-- Execute's addr_rb forwarding logic
	process(execute_in.is_imm, execute_in.imm_val, execute_in.addr_rb, memory_in.rd_addr, memory_in.alu_result, write_back_in.rd_addr, reg_file.data_w, reg_file.data_rb)
	begin
		if (execute_in.is_imm = '1') then
			alu_in_src2 <= execute_in.imm_val;
		else
			if (execute_in.addr_rb = memory_in.rd_addr) then
				alu_in_src2 <= memory_in.alu_result;
			elsif (execute_in.addr_rb = write_back_in.rd_addr) then
				alu_in_src2 <= reg_file.data_w;
			else
				alu_in_src2 <= reg_file.data_rb;
			end if;
		end if;
	end process;

	-- Execute's store_data forwarding logic
	process(execute_in.addr_rb, memory_in.rd_addr, memory_in.alu_result, write_back_in.rd_addr, reg_file.data_w, reg_file.data_rb)
	begin
		if (execute_in.addr_rb = memory_in.rd_addr) then
			memory_in_p0.store_data <= memory_in.alu_result;
		elsif (execute_in.addr_rb = write_back_in.rd_addr) then
			memory_in_p0.store_data <= reg_file.data_w;
		else
			memory_in_p0.store_data <= reg_file.data_rb;
		end if;
	end process;

	-- Execute's ALU in arith signal selection
	with execute_in.decoded_instruction select execute_in_arith <=
		'1' when ASM_SRAI | ASM_SRA,
		'1' when ASM_SUB | ASM_SLT | ASM_SLTU | ASM_SLTI | ASM_SLTIU,
		'0' when others;                -- set less than is a substraction

	-- Execute's ALU signed signal selection
	with execute_in.decoded_instruction select alu_signed <=
		'1' when ASM_JAL,
		'1' when ASM_JALR,
		'1' when ASM_ADDI,
		'1' when ASM_SLTI,
		'1' when ASM_SLT,
		'1' when ASM_ADD,
		'1' when ASM_SUB,
		'0' when others;

	-- Execute's ASM_JAL and ASM_JALR (pc + 4)
	with execute_in.decoded_instruction select memory_in_p0.alu_result <=
		decode_in.pc_carry(XLEN - 1 downto 0) when ASM_JAL | ASM_JALR,
		alu_result when others;

	-- Clocked process for EX to ME
	process(in_clk, in_rstn)
	begin
		if (in_rstn = '0') then
			memory_in.alu_result          <= (others => '0');
			memory_in.decoded_instruction <= ASM_NOP;
			memory_in.rd_addr             <= (others => '0');
			memory_in.store_data          <= (others => '0');
		elsif rising_edge(in_clk) then
			memory_in <= memory_in_p0;
		end if;
	end process;

	-- Memory
	process(memory_in)
	begin
		out_dmem_addr <= memory_in.alu_result(9 downto 0);

		write_back_in_p0.alu_result <= memory_in.alu_result;

		if (memory_in.decoded_instruction = ASM_SW) then
			out_dmem_we <= '1';
		else
			out_dmem_we <= '0';
		end if;

		write_back_in_p0.decoded_instruction <= memory_in.decoded_instruction;

		write_back_in_p0.rd_addr <= memory_in.rd_addr;

		out_dmem_write <= memory_in.store_data;
	end process;

	-- Clocked process for ME to WB
	process(in_clk, in_rstn)
	begin
		if (in_rstn = '0') then
			write_back_in.alu_result          <= (others => '0');
			write_back_in.decoded_instruction <= ASM_NOP;
			write_back_in.rd_addr             <= (others => '0');
		elsif rising_edge(in_clk) then
			write_back_in <= write_back_in_p0;
		end if;
	end process;

	-- Write Back
	process(write_back_in, in_dmem_read)
	begin
		if (write_back_in.decoded_instruction = ASM_LW) then
			reg_file.data_w <= in_dmem_read(XLEN - 1 downto 0);
		else
			reg_file.data_w <= write_back_in.alu_result;
		end if;

		case write_back_in.decoded_instruction is
			when ASM_BEQ => reg_file.we <= '0';
			when ASM_SW  => reg_file.we <= '0';
			when ASM_NOP => reg_file.we <= '0';
			when others  => reg_file.we <= '1';
		end case;

		reg_file.addr_w <= write_back_in.rd_addr;
	end process;

end architecture RTL;
