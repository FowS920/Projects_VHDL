
;; ------------------------------------------------------------------
;; Project     : ELE8304 : Circuits intégrés à très grande échelle
;; Description : Conception d'un microprocesseur mini-riscv
;; ------------------------------------------------------------------
;; File        : fibo.asm
;; Author      : Mickael Fiorentino  <mickael.fiorentino@polymtl.ca>
;; Lab         : grm@polymtl
;; Created     : 2017-08-02
;; Last update : 2017-09-07
;; ------------------------------------------------------------------
;; Description : Test assembly program for the mini-riscv processor
;;               20 first Fibonacci series saved in dmem
;; ------------------------------------------------------------------
	

start:	
	beq   x2  x0  main
	addi  x5  x0  0xaaa
	beq   x10 x5  pass 

fail:
	lui   x5  0xfffff
	addi  x6  x0  0xfff
	or    x7  x5  x6
	addi  x2  x0  0
	sw    x7  x2  0
	jal   x0  end
	
pass:
	lui   x5  0xaaaaa
	addi  x6  x0  0xaaa
	xor   x7  x5  x6
	andi  x2  x0  0
	sw    x7  x2  0
	jal   x0  end		

main:
	addi  x2  x0  1
	slli  x2  x2  2
	jal   x1  fibo
	jal   x0  start
	nop
	nop
	nop
	nop

fibo:
	addi  x11  x0  19
	addi  x12  x0  1
	and   x5   x0  x0
	addi  x6   x0  1	
	sw    x5   x2  0
	sw    x6   x2  4
loop:
	sltiu x28 x11 1
	beq   x28 x12 endloop
	sub   x11 x11 x12
	lw    x5  x2  0
	lw    x6  x2  4
	add   x7  x5  x6
	sw    x7  x2  8
	srai  x2  x2  2
	addi  x2  x2  1
	slli  x2  x2  2
	jal   x0  loop
endloop:
	addi  x10 x0  0xaaa
	jalr  x0  x1  0
	
end:
	nop
	nop
	nop
	nop
	nop
	
