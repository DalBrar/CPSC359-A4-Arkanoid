@ CPSC 359 Assignment 4 - Arkanoid
@	- this file is basically assignment 3 with a few minor modifications
@ Written by: Dalbir Brar
@ Student ID: 002 968 97

@ Static messages section
.section    .text
con_init:	.asciz	"Initializing Controller...\n"
con_done:	.asciz	"Controller Initialized.\n"
endOfcon:	.align

@ Code section

/*
 * initController:
 *		- Initializes controller GPIO pins for input and output
 */
.global initController
initController:
	push	{r4-r10, lr}			@ remember calling system's return position

	ldr		r0, =con_init
	bl		printf

	@ Get GPIO base address and store in memory for future use
	bl		getGpioPtr		
	ldr		r1, =gpioAddr
	str		r0, [r1]

	@ initialize GPIO pin 11 (CLK)
	mov		r0, #11					@ input pin 11
	mov		r1, #1					@ input code: 1 for output
	bl		init_GPIO
	
	@ initialize GPIO pin 9 (LATCH)
	mov		r0, #9					@ input pin 9
	mov		r1, #1					@ input code: 1 for output
	bl		init_GPIO
	
	@ initialize GPIO pin 10 (DATA)
	mov		r0, #10					@ input pin 10
	mov		r1, #0					@ input code: 0 for input
	bl		init_GPIO

	ldr		r0, =con_done
	bl		printf

	b		ret
	
/*
 * read_snes
 * input: none
 * returns: returns 16 bits of 1's or 0's where 0 = button pressed
 *			15	14	13	12	11	10	9	8	7	6	5	4	3	2	1	0
 * 		   [nu][nu][nu][nu]	RB	LB	X	A	D>	D<	Dv	D^	Str	Sel	Y	B
 */
.global	read_snes
read_snes:	
	push	{r4-r10, lr}			@ remember calling system's return position
	
	pulse_r	.req	r4				@ Register Aliases for read_data subroutine
	cntrlr	.req	r5
	temp_r	.req	r6
	
	mov		cntrlr, #0				@ reset controller input to 0
		
	mov		r0, #1					@ set latch = 1
	bl		write_latch
	
	mov		r0, #1					@ set clock = 1
	bl		write_clock
	
	mov		r0, #12					@ wait 12us
	bl		delayMicroseconds
	
	mov		r0, #0					@ set latch = 0
	bl		write_latch
	
	mov		pulse_r, #0				@ reset pulse	
	
	snes_loop:
	mov		r0, #6					@ wait 6us
	bl		delayMicroseconds

	mov		r0, #0					@ set clock = 0
	bl		write_clock

	bl		read_data				@ get pulse value
	cmp		r0, #1					@ compare returned value to 1
	moveq	temp_r,	#1				@ if r0 = 1:	set temp_r as 1
	lsleq	temp_r, pulse_r			@				lsl temp_r by the pulse iteration
	addeq	cntrlr, temp_r			@				add temp to the controller output
 
	mov		r0, #6					@ wait 6us
	bl		delayMicroseconds
	
	mov		r0, #1					@ set clock = 1
	bl		write_clock
	
	add		pulse_r, #1				@ increment pulse
	cmp		pulse_r, #16
	blt		snes_loop				@ return to loop if less than 17 pulses

	mov		r0, #0					@ reset clock = 0 and return result buttons pressed
	bl		write_clock
	
	mov		r0, cntrlr				@ load return value of all button states

	.unreq		pulse_r
	.unreq		cntrlr
	.unreq		temp_r
	
	b		ret

/*
 * init_GPIO
 * input:
 *	r0 - line number
 *	r1 - function code
 * returns: void
 */
init_GPIO:
	@ Register Aliases for init_GPIO subroutine
	addr_r	.req	r4
	pin_r	.req	r5
	code_r	.req	r6
	
	mov		fp, sp					@ save position in calling code
	push	{r4-r10}
	
	ldr		addr_r, =gpioAddr		@ move virtual address into addr_r
	ldr		addr_r, [addr_r]		@ load address from virtual address
	mov		pin_r, r0				@ move line number to pin_r
	mov		code_r, r1				@ move function code into code_r

	GPIO_loop:
	cmp		pin_r, #9				@ compare GPIO pin# to 9
	subhi	pin_r, #10				@ subtract 10 if input pin# higher than 9
	addhi	addr_r, #4				@ increment base GPIO register by 4
	bhi		GPIO_loop				@ loop until line number is less than 9
	
	add		pin_r, pin_r, lsl #1	@ get pin's offset position
	
	@ load > clear > set > store GPFSEL{n} code
	ldr		r1, [addr_r]			@ copy GPFSEL{n} into r1
	mov		r2, #7					@ b0111
	lsl		r2, pin_r				@ index of 1st bit for pin
	bic		r1, r2					@ clear pin bits
	mov		r3, code_r				@ function code
	lsl		r3, pin_r				@ move code to right offset position
	orr		r1, r3					@ set GPFSEL{n} function in r1
	str		r1, [addr_r]			@ write back to GPFSEL{n}

	.unreq		addr_r
	.unreq		pin_r
	.unreq		code_r
	
	pop		{r4-r10}
	bx		lr						@ return to position in calling code


/*
 * write_latch
 * input:
 *	r0 - value to write (0 or 1)
 * returns: void
 */
write_latch:
	@ Register Aliases for write_latch subroutine
	addr_r	.req	r4
	pin_r	.req	r5
	code_r	.req	r6
	bit_r	.req	r7

	mov		fp, sp					@ save position in calling code
	push	{r4-r10}

	ldr		addr_r, =gpioAddr		@ move virtual address into addr_r
	ldr		addr_r, [addr_r]		@ load address from virtual address
	mov		pin_r, #9				@ set pin_r as LATCH line
	mov		code_r, r0				@ move value to write (0 or 1) into code_r
	
	mov		bit_r, #1				@ set bit_r to single bit
	lsl		bit_r, pin_r			@ align bit for pin #9
	teq		code_r, #0				@ compare code to 0
	streq	bit_r, [addr_r, #40]	@ if code = 0, str GPCLR0 to GPIO reg (0x28)
	strne	bit_r, [addr_r, #28]	@ if code = 1, str GPSET0 to GPIO reg (0x1C)

	.unreq		addr_r
	.unreq		pin_r
	.unreq		code_r
	.unreq		bit_r
	
	pop		{r4-r10}
	bx		lr						@ return to position in calling code
	
/*
 * write_clock
 * input:
 *	r0 - value to write (0 or 1)
 * returns: void
 */
write_clock:
	@ Register Aliases for write_clock subroutine
	addr_r	.req	r4
	pin_r	.req	r5
	code_r	.req	r6
	bit_r	.req	r7

	mov		fp, sp					@ save position in calling code
	push	{r4-r10}

	ldr		addr_r, =gpioAddr		@ move virtual address into addr_r
	ldr		addr_r, [addr_r]		@ load address from virtual address
	mov		pin_r, #11				@ set pin_r as CLOCK line
	mov		code_r, r0				@ move value to write (0 or 1) into code_r
	
	mov		bit_r, #1				@ set bit_r to single bit
	lsl		bit_r, pin_r			@ align bit for pin #11
	teq		code_r, #0				@ compare code to 0
	streq	bit_r, [addr_r, #40]	@ if code = 0, str GPCLR0 to GPIO reg (0x28)
	strne	bit_r, [addr_r, #28]	@ if code = 1, str GPSET0 to GPIO reg (0x1C)

	.unreq		addr_r
	.unreq		pin_r
	.unreq		code_r
	.unreq		bit_r
	
	pop		{r4-r10}
	bx		lr						@ return to position in calling code
	
/*
 * read_data
 * input: none
 * returns: data state (0 or 1)
 */
read_data:
	@ Register Aliases for read_data subroutine
	addr_r	.req	r4
	pin_r	.req	r5
	read_r	.req	r6
	bit_r	.req	r7
	
	mov		fp, sp					@ save position in calling code
	push	{r4-r10}

	ldr		addr_r, =gpioAddr		@ move virtual address into addr_r
	ldr		addr_r, [addr_r]		@ load address from virtual address
	mov		pin_r, #10				@ set pin_r as DATA line
	
	ldr		read_r, [addr_r, #52]	@ Load pin values
	mov		bit_r, #1				@ set bit_r to 1 bit
	lsl		bit_r, pin_r			@ align bit for pin #10
	and		read_r, bit_r			@ and input bits with wanted bit for pin#10 masking everything else
	teq		read_r, #0				@ compare read bit with 0
	moveq	r0, #0					@ return 0 if bit is 0
	movne	r0, #1					@ return 1 if bit is 1

	.unreq		addr_r
	.unreq		pin_r
	.unreq		read_r
	.unreq		bit_r
	
	pop		{r4-r10}
	bx		lr						@ return to position in calling code

/*
 * wait_button_release:
 *	- continue reading controller until no buttons are pressed
 */
.global wait_button_release
wait_button_release:
	push		{lr}

	wbr_loop:
		bl		read_snes
		mov		r1, #65535
		cmp		r0, r1				@ check if no buttons pressed on controller
		bne		wbr_loop			@	if false: wait for button realse
	
	pop			{pc}

/*
 * wait_button_input:
 *	- continue reading controller until no buttons are pressed
 */
.global wait_button_input
wait_button_input:
	push		{lr}

	bl		wait_button_release
	wbi_loop:
		bl		read_snes
		mov		r1, #65535
		cmp		r0, r1				@ check if no buttons pressed on controller
		beq		wbi_loop			@	if true: wait for button input
	bl		wait_button_release
	
	pop			{pc}

@ Data section
.section    .data
gpioAddr:	.int	0

.end
