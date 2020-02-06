@ CPSC 359 Assignment 4 - Arkanoid
@		- this is the main program
@ Written by: Dalbir Brar
@ Student ID: 002 968 97

@ Static messages section
.section    .text
auth1:	.asciz	"CPSC 359 Assignment 4 - Arkanoid\n"
auth2:	.asciz	"Made by: Dalbir Brar, Student ID: 002 968 97\n\n"
run_m:	.asciz	"Game running...\n\n"
exit_m:	.asciz	"\nProgram is terminating...\n\n"

.align

@ Code section
.global main
.global ret
main:
	push	{r4-r10, lr}			@ remember calling system's return position
	
	cntrlr		.req	r4
	ballCycle	.req	r5
	ballSpeed	.req	r6
	pupCycle		.req	r7

	ldr		r0, =auth1				@ Print author info
	bl		printf
	ldr		r0, =auth2
	bl		printf

	bl		initController			@ Initialize Controller
	bl		initGraphics			@ Initialize Graphics
	
	ldr		r0, =run_m				@ console msg to run game
	bl		printf

main_menu:
	bl		start_menu				@ launch start menu
	
	cmp		r0, #1					@ check start menu choice
	bne		exit					@ exit or run game

	@ run game
init_game:
	bl		initScore				@ initialize scoreboard
	bl		initPowerups			@ initialize powerups
	mov		r0, #0					@ set input for initGame to initial map
	
init_play:
	bl		initGame				@ initialize game
	bl		displayScoreboard
	mov		ballCycle, #0			@ initialize ballCycle
	mov		pupCycle, #0				@ initialize powerup cycle
	
	game_running:
		mov		r0, #4000				@ slow down movement
		bl		delayMicroseconds
		
		ldr		ballSpeed, =ball_speed
		ldr		ballSpeed, [ballSpeed]	@ load ball speed
		
		add		ballCycle, #1			@ increment ballCycle
		cmp		ballCycle, ballSpeed	@ loop ballCycle back to 0 if reaches Max
		movge	ballCycle, #0
		
		add		pupCycle, #1				@ increment cycle
		cmp		pupCycle, #3				@ loop cycle back to 0 if reaches Max
		moveq	pupCycle, #0
		
		bl		read_snes
		mov		cntrlr, r0
		
		tst		cntrlr, #0b1000			@ test cntrlr for Start button
		bne		continue				@	if FALSE: continue game play
		bleq	pause_menu				@	if TRUE: open Pause menu
		
		cmp		r0, #1					@ compare pause_menu output to 1
		blt		clear_n_cont			@	if 0 = clear pause menu and continue
		beq		init_game				@	if 1 = restart game
		bl		wait_button_release		@	if 2 = go to main menu but first wait for button release
		b		main_menu
	
	clear_n_cont:
		bl		resume_game
	
	continue:
		tst		cntrlr, #0b100000000	@ test cntrlr for A button
		moveq	r1, #3					@	A press: speed = 3
		movne	r1, #1					@		else speed = 1
		ldr		r0, =paddle_speed
		str		r1, [r0]				@ save speed value in variable
		
		tst		cntrlr, #0b1000000		@ test cntrlr for D-Pad Left
		bleq	move_paddle_left
		
		tst		cntrlr, #0b10000000		@ test cntrlr for D-Pad Right
		bleq	move_paddle_right
		
		ldr		r0, =paddle_sticky		@ load paddle sticky flag
		ldr		r1, [r0]
		cmp		r1, #1					@ check if flag TRUE
		bne		ball_movement			@	if FALSE: move ball
		tst		cntrlr, #0b1			@ 	else test cntrlr for B button
		moveq	r1, #0					@		if B pressed: change paddle_sticky = FALSE
		streq	r1, [r0]				@				and save
		
		b		game_running_end
		
	ball_movement:
		tst		cntrlr, #0b100000000000		@ test cntrlr for Right Bumper
		bleq	move_ball					@	if Right Bumper pressed: FAST ball mode
		beq		game_running_end
	
	
		cmp		ballCycle, #0
		bleq	move_ball				@ control ball speed
		
	game_running_end:
		cmp		pupCycle, #0
		bleq	powerups_fall			@ control powerup fall speed
		
		cmp		pupCycle, #0
		bleq	displayScoreboard		@ control speed of scoreboard update
		
		bl		draw_lava
		bl		check_winlose_cond
		cmp		r0, #1					@ check winlose condition flag
		blt		game_lose				@	if flag=0: go to lose game
		bgt		game_win				@	if flag=2: go to win game
										@	else: check if ball dead and act accordingly
		
		cmp		r1, #1					@ check if ball is dead
		moveq	r0, #1					@ set input for initGame to resume map
		beq		init_play				@	if TRUE: reset playing area
		
		b		game_running
		
	game_lose:
		mov		r0, #1					@ pass in 1 for lose
		bl		draw_winlose
		bl		wait_button_input
		b		main_menu
	
	game_win:
		mov		r0, #0					@ pass in 0 for win
		bl		draw_winlose
		bl		wait_button_input
		b		main_menu
	
exit:
	mov		r0, #1					@ draw quit screen
	bl		draw_img_full
	
	ldr		r0, =exit_m				@ Print exit message
	bl		printf
	ldr		r0, =auth2				@ Print author info
	bl		printf
	mov		r0, #0					@ exit code to exit normally
	
	.unreq		cntrlr
	.unreq		ballCycle
	.unreq		ballSpeed
	.unreq		pupCycle
	
ret:
	pop		{r4-r10, pc}			@ return to calling system

@ ==================================================
@ subroutines section

/*
 * check_winlose_cond:
 *		- checks the win/lose conditions and returns an appropriate value.
 *		- Also checks if ball in lava and kills a life if true
 *	Output:
 *		r0 = win/lose condition (0 = lose, 1 = continue, 2 = win)
 *		r1 = ball death TRUE/FALSE (0 = FALSE, 1 = TRUE)
 */
check_winlose_cond:
	push	{r4-r10, lr}
	
	winlose		.req	r4
	deathFlag	.req	r5
	scrbd		.req	r6
	ballAddr	.req	r7
	
	mov		winlose, #1					@ set initial win/lose condition to continue
	mov		deathFlag, #0				@ set initial ball death flag to FALSE
	ldr		scrbd, =scoreboard			@ load scoreboard address
	ldr		ballAddr, =ball_coords		@ load ball_coords address
	
	ldr		r0, [ballAddr, #4]			@ r0 = ball current y coord
	ldr		r1, =#533					@ r1 = top of lava pit coord
	cmp		r0, r1						@ check if ball in lava pit
	bgt		cwc_setDeathFlag			@	if TRUE: set deathFlag TRUE & decrement life
	b		cwc_checkWinLose			@	else: continue to check win/lose condition
	
	cwc_setDeathFlag:
		mov		deathFlag, #1				@ set deathFlag to TRUE
		
		ldr		r0, [scrbd, #4]				@ r0 = lives
		sub		r0, #1						@ decrement lives by 1
		str		r0, [scrbd, #4]				@ save lives to scoreboard
		
		mov		r0, #0
		strb	r0, [scrbd, #16]			@ remove powerup 1
		strb	r0, [scrbd, #17]			@ remove powerup 2
	
	cwc_checkWinLose:
		ldr		r0, [scrbd, #4]				@ r0 = lives
		cmp		r0, #0						@ check if lives less than 0
		movlt	winlose, #0					@	if TRUE: set winlose to lose
		blt		cwc_exit
		
		ldr		r0, [scrbd, #12]			@ r0 = total number of blocks broken
		ldr		r1, [scrbd, #8]				@ r1 = total number of blocks to break
		cmp		r0, r1						@ check if blocks broken is >= blocks to break
		movge	winlose, #2					@	if TRUE: set winlose to win
		
	cwc_exit:
		mov		r0, winlose					@ return r0 as winlose condition
		mov		r1, deathFlag				@ return r1 as deathFlag
		
	.unreq		winlose
	.unreq		deathFlag
	.unreq		scrbd
	.unreq		ballAddr
	
	b		ret


/*
 * start_menu:
 *	- Displays the startmenu and waits for controller input to make a selection
 *	Controls:
 *		up/down = change option
 *		start/A = choose selection
 *	Output:
 *		r0 = choice made
 */
start_menu:
	push	{r4-r10, lr}
	
	choice		.req	r4
	cntrlr		.req	r5
	cntrlr_last	.req	r6
	
	mov		r0, #0					@ draw start menu
	bl		draw_img_full
	
	mov		choice, #1				@ default choice is Start
	mov		cntrlr_last, #65535		@ initialize last controller button press
	mov		cntrlr, cntrlr_last		@ initialize cntrlr
	
	smenu_outerloop:
		cmp		choice, #1			@ if choice > 1, set to 0
		movgt	choice, #0
	
		mov		r0, #176			@ set xBase
		mov		r1, #368			@ set yBase
		
		cmp		choice, #1			@ check if choice = start
		bleq	draw_smenu_start	@		true = draw start button selected
		blne	draw_smenu_quit		@		else = draw quit button selected
		
		smenu_waitInput:
			bl		read_snes
			mov		cntrlr, r0
			
			cmp		cntrlr, cntrlr_last	@ compare current button presses to last
			beq		smenu_waitInput		@ if same then keep waiting for button release
			mov		cntrlr_last, cntrlr	@ if different then reset cntrlr_last.
			
			tst		cntrlr, #0b1000		@ test cntrlr AND Start button
			beq		smenu_exit			@ and exit
			
			tst		cntrlr, #0b100000000 @ test cntrlr AND A button
			beq		smenu_exit			@ and exit
			
			tst		cntrlr, #0b10000	@ test cntrlr AND D-Pad up
			moveq	choice, #1			@		if equal increment choice
			moveq	cntrlr_last, cntrlr	@		move cntrlr into cntrlr_last to prevent multi-presses
			beq		smenu_outerloop		@		and draw new selection
			
			tst		cntrlr, #0b100000	@ test cntrlr AND D-Pad down
			moveq	choice, #0			@		if equal increment choice
			moveq	cntrlr_last, cntrlr	@		move cntrlr into cntrlr_last to prevent multi-presses
			beq		smenu_outerloop		@		and draw new selection
			
			b		smenu_waitInput		@ else await input from controller

	smenu_exit:
	bl		wait_button_release
	
	mov		r0, choice			@ return choice
	
	.unreq		choice
	.unreq		cntrlr
	.unreq		cntrlr_last
	
	b		ret

/*
 * pause_menu:
 *	- Displays the pause menu and waits for controller input to make a selection
 *	Controls:
 *		up/down = change option
 *		start 	= Resume
 *		A btn	= make selected choice
 *	Output:
 *		r0 = choice made (0 = Resume, 1 = Restart, 2 = Main Menu)
 */
pause_menu:
	push	{r4-r10, lr}
	
	frame		.req	r4
	choice		.req	r5
	cntrlr		.req	r6
	cntrlr_last	.req	r7
	
	mov		frame, #0					@ initialize frame to 0
	mov		choice, #0					@ initialize choice to 0
	
	bl		wait_button_release
	
	pmenu_loop:
		mov		r0, frame				@ load frame and draw pause menu title
		bl		draw_pmenu
		
		mov		r0, choice				@ load choice and draw options
		bl		draw_pmenu_options
		
		add		frame, #1				@ increment frame
		cmp		frame, #10				@ check if frame = 10
		moveq	frame, #0				@	if true: reset frame to 0
	
		bl		read_snes
		mov		cntrlr, r0				@ save controller output
		
		cmp		cntrlr, cntrlr_last		@ compare current button presses to last
		beq		pmenu_loop				@ if same then keep waiting for button change
		mov		cntrlr_last, cntrlr		@ if different then reset cntrlr_last and continue
		
		tst		cntrlr, #0b1000 		@ test cntrlr AND Start button
		moveq	choice, #0				@ set choice as Resume
		beq		pmenu_exit				@	and exit pause menu
		
		tst		cntrlr, #0b100000000 	@ test cntrlr AND A button
		beq		pmenu_exit				@	if A pressed: exit pause menu
		
		tst		cntrlr, #0b10000 		@ test cntrlr AND D-Pad Up
		subeq	choice, #1				@	if Up pressed: decrement choice
		
		tst		cntrlr, #0b100000 		@ test cntrlr AND D-Pad Down
		addeq	choice, #1				@	if Down pressed: increment choice
		
		cmp		choice, #0				@ compare choice to 0
		movlt	choice, #2				@	if choice < 0: choice = 2
		cmp		choice, #2				@ compare choice to 2
		movgt	choice, #0				@	if choice > 2: choice = 0
	
		mov		r0, #6					@ delay loop for visual effect
		bl		delayCentiseconds
		
		b		pmenu_loop
	
	pmenu_exit:
	bl		wait_button_release
	
	mov		r0, choice
	
	.unreq		frame
	.unreq		choice
	.unreq		cntrlr
	.unreq		cntrlr_last
	
	b		ret

/*
 * initGame:
 *	- Initializes the game and sprites
 *	Input:
 *		r0 = brick map to draw (0 = initial, 1 = current)
 */
initGame:
	push	{r4,lr}
	
	input	.req	r4
	
	mov		input, r0				@ save input choice
	
	mov		r0, #2					@ draw game background
	bl		draw_img_full
	
	mov		r0, #208				@ draw paddle
	bl		draw_paddle
	
	ldr		r0, =paddle_sticky		@ load address of paddle_sticky
	mov		r1, #1					@ set r1 = 1
	str		r1, [r0]				@ set paddle to sticky
	
	mov		r0, #234				@ ball x coord
	mov		r1, #484				@ ball y coord
	bl		draw_ball
	
	ldr		r0, =ball_coords		@ load ball_coords address
	mov		r1, #1
	strb	r1, [r0, #16]			@ set angle to 45 degrees
	strb	r1, [r0, #18]			@ set Vertical direction to UP
	mov		r1, #2
	strb	r1, [r0, #17]			@ set Horizontal direction to RIGHT
	
	cmp		input, #0				@ check if input = 0 and set map accordingly
	ldreq	r0, =brick_map_init
	ldrne	r0, =brick_map
	bl		load_bricks
	
	ldr		r3, =ball_speed
	mov		r1, #4					@ reset initial ball speed
	str		r1, [r3]				@ save ball speed
	
	.unreq		input
	
	pop		{r4,pc}

/*
 * initPowerups:
 *		- initializes the start state of the powerups
 */
initPowerups:
	push	{lr}
	
	ldr		r0, =powerup1			@ load powerup1 address
	mov		r1, #288
	str		r1, [r0, #4]			@ set current y coord
	mov		r1, #0
	strb	r1, [r0, #8]			@ set visible to NO
	ldr		r1, =#274
	str		r1, [r0, #9]			@ reset brickNum
	
	ldr		r0, =powerup2			@ load powerup2 address
	mov		r1, #288
	str		r1, [r0, #4]			@ set current y coord
	mov		r1, #0
	strb	r1, [r0, #8]			@ set visible to NO
	ldr		r1, =#280
	str		r1, [r0, #9]			@ reset brickNum
	
	ldr		r0, =scoreboard
	mov		r1, #0
	strb	r1, [r0, #16]			@ deactivate powerup 1
	strb	r1, [r0, #17]			@ deactivate powerup 2
	
	pop		{pc}

/*
 * enable_pup1:
 *		- enables powerup 1, sticky paddle
 */
.global enable_pup1
enable_pup1:
	push	{lr}
	
	ldr		r3, =powerup1
	mov		r1, #0
	strb	r1, [r3, #8]				@ set powerup 1 NOT visible anymore
	
	ldr		r0, [r3]					@ load xCoord
	ldr		r1, [r3, #4]				@ load yCoord
	mov		r2, #32						@ set width
	mov		r3, #16						@ set height
	bl		clear_img					@ erase powerup from view
	
	ldr		r3, =scoreboard
	mov		r1, #1
	strb	r1, [r3, #16]				@ set powerup 1 on scoreboard to ON
	
	pop		{pc}

/*
 * enable_pup2:
 *		- enables powerup 2, slow ball
 */
.global enable_pup2
enable_pup2:
	push	{lr}
	
	ldr		r3, =powerup2
	mov		r1, #0
	strb	r1, [r3, #8]				@ set powerup 2 NOT visible anymore
	
	ldr		r0, [r3]					@ load xCoord
	ldr		r1, [r3, #4]				@ load yCoord
	mov		r2, #32						@ set width
	mov		r3, #16						@ set height
	bl		clear_img					@ erase powerup from view
	
	ldr		r3, =scoreboard
	mov		r1, #1
	strb	r1, [r3, #17]				@ set powerup 2 on scoreboard to ON
	
	ldr		r3, =ball_speed
	ldr		r1, [r3]
	add		r1, #5						@ slowdown ball by 3
	str		r1, [r3]					@ save new ball speed
	
	pop		{pc}

/*
 * resume_game:
 *	- resumes the gameplay and sprites
 */
resume_game:
	push	{lr}
	
	mov		r0, #2					@ draw game background
	bl		draw_img_full
	
	ldr		r1, =paddle_coords
	ldr		r0, [r1]				@ load paddle position & draw paddle
	bl		draw_paddle

	ldr		r1, =ball_coords
	ldr		r0, [r1]				@ ball x coord
	ldr		r1, [r1, #4]			@ ball y coord
	bl		draw_ball
	
	ldr		r0, =brick_map
	bl		load_bricks
	
	bl		displayScoreboard
	
	pop		{pc}

/*
 * load_bricks:
 *	- Loads the state of bricks from the brick map
 *	Input:
 *		r0 = the desired brick map to load
 */
load_bricks:
	push	{r4-r10, lr}
	
	mapAddr		.req	r4
	xCoord		.req	r5
	yCoord		.req	r6
	brickNum	.req	r7
	brickType	.req	r8
	
	mov		mapAddr, r0				@ save map address
	mov		xCoord, #0				@ initialize x coordinate
	mov		yCoord, #0				@ initialize y coordinate
	mov		brickNum, #0			@ initialize brick num
	
	lb_outerloop:
		mov		xCoord, #0			@ reset x coordinate
		
		lb_innerloop:
			ldrb	brickType, [mapAddr, brickNum]	@ load byte of brickType from map Address offset by brick number
			sub		brickType, #48					@ adjust ASCII value to brickType value
			
			cmp		brickType, #0					@ check brickType value
			movlt	brickType, #0					@ if < 0 set brickType to 0 <Failsafe incase user enters invalid characters>
			
			mov		r0, xCoord						@ pass x grid coord
			mov		r1, yCoord						@ pass y grid coord
			mov		r2, brickType					@ pass brickType
			bl		draw_brick						@ draw brick

			add		brickNum, #1					@ increment brickNum
			add		xCoord, #1						@ increment x grid coord
			
			cmp		xCoord, #15						@ compare x grid coord with 15
			blt		lb_innerloop					@ if <15: repeat innerloop
		
		add		yCoord, #1			@ increment y grid coord
		cmp		yCoord, #25			@ compare y grid coord with 25
		blt		lb_outerloop		@ if < 25: repeat outerloop
	
	.unreq		mapAddr
	.unreq		xCoord
	.unreq		yCoord
	.unreq		brickNum
	.unreq		brickType
	
	b		ret

/*
 * delayCentiseconds:
 *	- delays processing by input number of centiseconds.
 *	Input:
 *		r0 = # of centiseconds
 */
.global delayCentiseconds
delayCentiseconds:
	push	{r4-r10, lr}
	
	input	.req	r4
	counter	.req	r5
	
	mov		input, r0				@ save input
	mov		counter, #0				@ set counter to 0
	
	dcs_loop:
		mov		r0, #10000
		bl		delayMicroseconds
		
		add		counter, #1				@ increment counter
		
		cmp		counter, input			@ compare counter to total loops
		blt		dcs_loop				@	if < totalLoops: loop
	
	.unreq		input
	.unreq		counter
	
	b		ret

/*
 * brick_map_init:
 *	- used initialize bricks at start of game on grid of 15 x 25 where each cell is 32x16
 *	- NOTE: outside single digits on both left and right are reserved for Walls
 *	- NOTE: do not place bricks in reserved areas or player may not be able to win
 *	Variables:
 *		0 = clear area
 *		1 = gray brick
 *		2 = yellow brick
 *		3 = red brick
 */
.global brick_map_init
brick_map_init:
	.ascii	"000000000000000"	@ RxC: 15 x 0 RESERVED for Black Text Area
	.ascii	"000000000000000"	@ RxC: 15 x 1 RESERVED for Black Text Area
	.ascii	"000000000000000"	@ RxC: 15 x 2 RESERVED for Black Text Area
	.ascii	"000000000000000"	@ RxC: 15 x 3 RESERVED for top wall
	.ascii	"000000000000000"	@ RxC: 15 x 4 RESERVED for top wall
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000010000010000"
	.ascii	"000010000010000"
	.ascii	"000001000100000"
	.ascii	"000001000100000"
	.ascii	"000033333330000"
	.ascii	"000033333330000"
	.ascii	"000331333133000"
	.ascii	"000221222122000"
	.ascii	"002222222222200"
	.ascii	"002222222222200"
	.ascii	"001111111111100"
	.ascii	"001011111110100"
	.ascii	"001010000010100"
	.ascii	"001010000010100"
	.ascii	"000001101100000"
	.ascii	"000001101100000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
.align

@ Data section
.section    .data

@ brick_map used to save state of bricks for checking collision
.global brick_map
brick_map:
	.ascii	"000000000000000"	@ RxC: 15 x 0 RESERVED for Black Text Area
	.ascii	"000000000000000"	@ RxC: 15 x 1 RESERVED for Black Text Area
	.ascii	"000000000000000"	@ RxC: 15 x 2 RESERVED for Black Text Area
	.ascii	"000000000000000"	@ RxC: 15 x 3 RESERVED for top wall
	.ascii	"000000000000000"	@ RxC: 15 x 4 RESERVED for top wall
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	.ascii	"000000000000000"
	
.align

.global paddle_coords
paddle_coords:
	.int	0		@  0= current x coord
	.int	0		@  4= old x coord

.global paddle_speed
paddle_speed:
	.int	1		@ speed of paddle movement, 1 = normal, >1 = faster

.global paddle_sticky
paddle_sticky:
	.int	1		@ initial state of paddle, 0 = false, 1 = true

.global ball_coords
ball_coords:
	.int	0		@  0= current x coord
	.int	0		@  4= current y coord
	.int	0		@  8= old x coord
	.int	0		@ 12= old y coord
	.byte	1		@ 16= angle (1 = 45 approx, 2 = 60 approx)
	.byte	2		@ 17= Horizontal direction (1=Left, 2=Right)
	.byte	1		@ 18= Vertical direction (1=Up, 2=Down)

ball_speed:
	.int	5		@ ball speed cycle max value, lower = faster, min=0

.global powerup1
powerup1:			@ xGrid: 4, yGrid: 18, brickNum: 274
	.int	128		@ 0 = x coord constant
	.int	288		@ 4 = current y coord
	.byte	0		@ 8 = visible (0 = no, 1 = yes)
	.int	274		@ 9 = brickNum

.global powerup2
powerup2:			@ xGrid: 10, yGrid: 18, brickNum: 280
	.int	320		@ 0 = x coord constant
	.int	288		@ 4 = current y coord
	.byte	0		@ 8 = visible (0 = no, 1 = yes)
	.int	280		@ 9 = brickNum

.end
