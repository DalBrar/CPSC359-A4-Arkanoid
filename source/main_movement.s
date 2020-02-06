@ CPSC 359 Assignment 4 - Arkanoid
@		- this file contains all movement subroutines
@ Written by: Dalbir Brar
@ Student ID: 002 968 97

@ Static messages section
.section    .text

@ Code section


/*
 * move_paddle_left:
 *		- moves paddle left if allowable (no wall) & ball if paddle sticky
 */
.global move_paddle_left
move_paddle_left:
	push	{r4-r10, lr}
	
	varAddr		.req	r10
	varVal		.req	r9
	speed		.req	r8
	wall		.req	r7
	xCoord		.req	r8
	yCoord		.req	r9
	
	ldr		varAddr, =paddle_coords			@ load address of paddle_coords
	ldr		varVal, [varAddr]				@ load current paddle coordinate
	
	ldr		speed, =paddle_speed
	ldr		speed, [speed]					@ load speed value
	
	ldr		wall, =#32						@ wall = left wall
	
	cmp		varVal, wall					@ check if paddle xCoord at left wall
	beq		mpl_continue					@	if true, skip movement
	sub		varVal, speed					@	else move by speed
	
	cmp		varVal, wall					@ failsafe to check if xCoord less than 32
	movlt	varVal, wall					@		if less than 32, set to 32
	
	mov		r0, varVal						@ pass in xCoord
	bl		draw_paddle						@ draw paddle
		
	mpl_check_sticky:
	@ move ball if paddle is sticky
	ldr		varAddr, =paddle_sticky			@ load address of paddle_sticky
	ldr		varVal, [varAddr]				@ get state of paddle stickyness
	
	cmp		varVal, #1						@ check if paddle sticky is TRUE
	bne		mpl_continue					@	if FALSE: exit
	ldr		r3, =ball_coords				@	if TRUE:
	mov		r2, #1
	strb	r2, [r3, #17]					@			set ball direction to LEFT
	mov		r0, speed						@			pass speed
	bl		move_ball_horizontal			@			and move ball
	
	ldr		varAddr, =ball_coords
	ldr		r1, [varAddr, #4]				@ pass ball y coords
	bl		draw_ball						@ and draw ball
	
	mpl_continue:
	.unreq		varAddr
	.unreq		varVal
	.unreq		speed
	.unreq		wall
	.unreq		xCoord
	.unreq		yCoord
	
	b		ret
	
/*
 * move_paddle_right:
 *		- moves paddle right if allowable (no wall) & ball if paddle sticky
 */
.global move_paddle_right
move_paddle_right:
	push	{r4-r10, lr}
	
	varAddr		.req	r10
	varVal		.req	r9
	speed		.req	r8
	wall		.req	r7
	
	ldr		varAddr, =paddle_coords			@ load address of paddle_coords
	ldr		varVal, [varAddr]				@ load current paddle coordinate
	
	ldr		speed, =paddle_speed
	ldr		speed, [speed]					@ load speed value
	
	ldr		wall, =#384						@ wall = rightWall - paddleWidth = 448 - 64
	
	cmp		varVal, wall					@ check if paddle xCoord at right wall
	beq		mpr_continue					@	if true, skip movement
	add		varVal, speed					@	else move by speed
	
	cmp		varVal, wall					@ failsafe to check if xCoord greater than 384
	movgt	varVal, wall					@		if greater than 384, set to 384
	
	mov		r0, varVal						@ pass in xCoord
	bl		draw_paddle						@ draw paddle
	
	ldr		varAddr, =paddle_sticky			@ load address of paddle_sticky
	ldr		varVal, [varAddr]				@ get state of paddle stickyness
	
	cmp		varVal, #1						@ check if paddle sticky is TRUE
	bne		mpr_continue					@	if FALSE: exit
	ldr		r3, =ball_coords				@	if TRUE:
	mov		r2, #2
	strb	r2, [r3, #17]					@			set ball direction to Right
	mov		r0, speed						@			pass speed
	bl		move_ball_horizontal			@			and move ball
	
	mpr_continue:
	.unreq		varAddr
	.unreq		varVal
	.unreq		speed
	.unreq		wall
	
	b		ret

/*
 * move_ball_horizontal:
 *		- moves ball if allowable (no wall)
 *	Input:
 *		r0 = number of pixels to move
 */
move_ball_horizontal:
	push	{r4-r10, lr}
	
	pixels		.req	r10
	ballAddr	.req	r9
	ballCoord	.req	r8
	ballDir		.req	r7
	wall		.req	r6
	temp		.req	r5
	loopCheck	.req	r4
	
	mov		pixels, r0						@ save number of pixels to move
	ldr		ballAddr, =ball_coords			@ load address of ball_coords
	ldr		ballCoord, [ballAddr]			@ load current ball X coordinate
	ldrb	ballDir, [ballAddr, #17]		@ load ball horizontal direction
	mov		loopCheck, #0					@ initialize loopCheck: used to prevent ball goin into infinite loop if stuck between paddle and wall
	
	mbh_loop:
		cmp		ballDir, #1					@ check ball direction
		bne		mbh_right					@	if =2: move right
											@	else: move left
	mbh_left:
		mov		temp, ballCoord				@ temp = ballCoord
		sub		temp, #1					@ calculate new coord after movement
		mov		r0, temp					@ pass temp x coord
		mov		r1, #1						@ pass left side
		bl		check_wall_horizontal
		cmp		r0, #1						@ check if result is wall
		beq		mbh_left_change				@	if TRUE: go to change direction
		sub		ballCoord, #1				@	else: update ballCoord for movement,
		sub		pixels, #1					@			decrement pixels
		b		mbh_continue				@			and continue
		
		mbh_left_change:
			add		loopCheck, #1			@ increment loopCheck
			cmp		loopCheck, #2			@ check if subroutine has looped back one whole circle
			beq		mbh_exit				@	if TRUE: exit
			
			mov		ballDir, #2				@	else: change ball direction to RIGHT
			b		mbh_right				@		and move right
		
	mbh_right:
		mov		temp, ballCoord				@ temp = ballCoord
		add		temp, #1					@ calculate new coord after movement
		mov		r0, temp					@ pass temp x coord
		mov		r1, #2						@ pass right side
		bl		check_wall_horizontal
		cmp		r0, #1						@ check if result is wall
		beq		mbh_right_change			@	if TRUE: go to change direction
		add		ballCoord, #1				@	else: update ballCoord for movement,
		sub		pixels, #1					@			decrement pixels
		b		mbh_continue				@			and continue
		
		mbh_right_change:
			add		loopCheck, #1			@ increment loopCheck
			cmp		loopCheck, #2			@ check if subroutine has looped back one whole circle
			beq		mbh_exit				@	if TRUE: exit
			
			mov		ballDir, #1				@	else: change ball direction to LEFT
			b		mbh_left				@		and move left
	
	mbh_continue:
		cmp		pixels, #0					@ check if pixels remain to move
		bgt		mbh_loop					@	if TRUE: loop back
	
	strb	ballDir, [ballAddr, #17]		@ update new ball horizontal direction
	
	ldr		ballAddr, =ball_coords
	ldr		r1, [ballAddr, #4]				@ pass ball y coords
	mov		r0, ballCoord					@ pass new ball x coord
	bl		draw_ball						@ and draw ball
	mbh_exit:
	.unreq		pixels
	.unreq		ballAddr
	.unreq		ballCoord
	.unreq		ballDir
	.unreq		wall
	.unreq		temp
	.unreq		loopCheck
	
	b		ret

/*
 * move_ball_vertical:
 *		- moves ball if allowable (no wall)
 *	Input:
 *		r0 = number of pixels to move
 */
move_ball_vertical:
	push	{r4-r10, lr}
	
	pixels		.req	r10
	ballAddr	.req	r9
	ballCoord	.req	r8
	ballDir		.req	r7
	wall		.req	r6
	temp		.req	r5
	loopCheck	.req	r4
	
	mov		pixels, r0						@ save number of pixels to move
	ldr		ballAddr, =ball_coords			@ load address of ball_coords
	ldr		ballCoord, [ballAddr, #4]		@ load current ball Y coordinate
	ldrb	ballDir, [ballAddr, #18]		@ load ball vertical direction
	mov		loopCheck, #0					@ initialize loopCheck: used to prevent ball goin into infinite loop if stuck between paddle and wall
	
	mbv_loop:
		cmp		ballDir, #1					@ check ball direction
		bne		mbv_down					@	if =2: move Down
											@	else: move Up
	mbv_up:
		mov		temp, ballCoord				@ temp = ballCoord
		sub		temp, #1					@ calculate new coord after movement
		mov		r0, temp					@ pass temp y coord
		mov		r1, #1						@ pass UP direction
		bl		check_wall_vertical
		cmp		r0, #1						@ check if result is wall
		beq		mbv_up_change				@	if TRUE: go to change direction
		sub		ballCoord, #1				@	else: update ballCoord for movement,
		sub		pixels, #1					@			decrement pixels
		b		mbv_continue				@			and continue
		
		mbv_up_change:
			add		loopCheck, #1			@ increment loopCheck
			cmp		loopCheck, #2			@ check if subroutine has looped back one whole circle
			beq		mbh_exit				@	if TRUE: exit
			
			mov	ballDir, #2
			b	mbv_down
		
	mbv_down:
		mov		temp, ballCoord				@ temp = ballCoord
		add		temp, #1					@ calculate new coord after movement
		mov		r0, temp					@ pass temp y coord
		mov		r1, #2						@ pass DOWN direction
		bl		check_wall_vertical
		cmp		r0, #1						@ check if result is wall
		beq		mbv_down_change				@	if TRUE: go to change direction
		add		ballCoord, #1				@	else: update ballCoord for movement,
		sub		pixels, #1					@			decrement pixels
		b		mbv_continue				@			and continue
		
		mbv_down_change:
			add		loopCheck, #1			@ increment loopCheck
			cmp		loopCheck, #2			@ check if subroutine has looped back one whole circle
			beq		mbh_exit				@	if TRUE: exit
			
			mov	ballDir, #1
			b	mbv_up
	
	mbv_continue:
		cmp		pixels, #0					@ check if pixels remain to move
		bgt		mbv_loop					@	if TRUE: loop back
	
	strb	ballDir, [ballAddr, #18]		@ update new ball vertical direction
	
	ldr		ballAddr, =ball_coords
	ldr		r0, [ballAddr]					@ pass ball x coords
	mov		r1, ballCoord					@ pass new ball y coord
	bl		draw_ball						@ and draw ball
	
	.unreq		pixels
	.unreq		ballAddr
	.unreq		ballCoord
	.unreq		ballDir
	.unreq		wall
	.unreq		temp
	.unreq		loopCheck
	
	b		ret

/*
 * check_wall_horizontal:
 *		- checks if the next pixel is a wall/brick on the specified side
 *	Input:
 *		r0 = current x coord
 *		r1 = side/direction (1 = LEFT, 2 = RIGHT)
 *	Output:
 *		r0 = TRUE/FALSE if wall (0 = False, 1 = True)
 */
check_wall_horizontal:
	push	{r4-r10, lr}
	
	ballVar		.req	r4
	ballCoord	.req	r5
	wall		.req	r6
	
	mov		ballCoord, r0				@ save current x coord to check
	
	cmp		r1, #1						@ check direction
	bne		cwh_right					@	if =2: check right walls
										@	else: check left walls
	cwh_left:
		@ check for wall block
		mov		wall, #31				@ set wall block at 31
		sub		ballCoord, #1			@ move ball 1 pixel over
		
		cmp		ballCoord, wall			@ check if ballCoord in Wall
		bgt		cwh_brick				@	if FALSE: continue checking bricks
		mov		r0, #1					@	if TRUE: set return flag to TRUE
		b		cwh_exit				@			and exit
		
	cwh_right:
		@ check for wall block
		ldr		wall, =#449				@ set wall block at 449
		add		ballCoord, #13			@ ballCoord = ballWidth(12) + 1 
		
		cmp		ballCoord, wall			@ check if ballCoord in Wall
		blt		cwh_brick				@	if FALSE: continue checking bricks
		mov		r0, #1					@	if TRUE: set return flag to TRUE
		b		cwh_exit				@			and exit
		
	cwh_brick:
		@ check for bricks
		ldr		ballVar, =ball_coords
		ldr		r1, [ballVar, #4]		@ pass current y coord
		mov		r0, ballCoord			@ pass current x coord
		bl		check_is_brick
		cmp		r0, #1					@ check if result is Brick
		subne	ballCoord, #13			@ adjust for ballWidth (check_is_paddle accounts for it)
		bne		cwh_paddle				@	if FALSE: check paddle
		mov		r0, #1					@	else: return TRUE and exit
		b		cwh_exit
		
	cwh_paddle:
		mov		r0, ballCoord			@ pass current x coord
		ldr		r1, [ballVar, #4]		@ pass current y coord
		bl		check_is_paddle			@ return value from check_is_paddle
		
	cwh_exit:
	.unreq		ballVar
	.unreq		ballCoord
	.unreq		wall
	
	b		ret

/*
 * check_wall_vertical:
 *		- checks if the next pixel is a wall/brick on the specified side
 *	Input:
 *		r0 = current y coord
 *		r1 = direction (1 = UP, 2 = DOWN)
 *	Output:
 *		r0 = TRUE/FALSE if wall (0 = False, 1 = True)
 */
check_wall_vertical:
	push	{r4-r10, lr}
	
	ballVar		.req	r4
	ballCoord	.req	r5
	wall		.req	r6
	
	mov		ballCoord, r0				@ save current y coord to check
	
	cmp		r1, #1						@ check direction
	bne		cwv_bottom					@	if =2: check bottom walls
										@	else: check top walls
	cwv_top:
		@ check for wall block
		mov		wall, #80				@ set wall block at 80
		sub		ballCoord, #1			@ move ball 1 pixel over
		
		cmp		ballCoord, wall			@ check if ballCoord in Wall
		bgt		cwv_brick				@	if FALSE: continue checking bricks
		mov		r0, #1					@	if TRUE: set return flag to TRUE
		b		cwv_exit				@			and exit
		
	cwv_bottom:
		@ check for wall block
		ldr		wall, =#551				@ set wall block at 551
		add		ballCoord, #13			@ ballCoord = ballWidth(12) + 1 
		
		cmp		ballCoord, wall			@ check if ballCoord in Wall
		blt		cwv_brick				@	if FALSE: continue checking bricks
		mov		r0, #1					@	if TRUE: set return flag to TRUE
		b		cwv_exit				@			and exit
		
	cwv_brick:
		@ check for bricks
		ldr		ballVar, =ball_coords
		ldr		r0, [ballVar]			@ pass current x coord
		mov		r1, ballCoord			@ pass current y coord
		bl		check_is_brick
		cmp		r0, #1					@ check if result is Brick
		subne	ballCoord, #13			@ adjust for ballWidth (check_is_paddle accounts for it)
		bne		cwv_paddle				@	if FALSE: check paddle
		mov		r0, #1					@	else: return TRUE and exit
		b		cwv_exit
		
	cwv_paddle:
		ldr		r0, [ballVar]			@ pass current x coord
		mov		r1, ballCoord			@ pass current y coord
		bl		check_is_paddle			@ return value from check_is_paddle
		
	cwv_exit:
	.unreq		ballVar
	.unreq		ballCoord
	.unreq		wall
	
	b		ret

/*
 * check_is_brick:
 *	- check if given x,y coordinate is brick. If coord IS brick, decrement brick and re-draw
 *	Input:
 *		r0 = x coordinate
 *		r1 = y coordinate
 *	Ouput:
 *		r0 = TRUE/FALSE if brick (0 = false, 1 = true)
 */
check_is_brick:
	push	{r4-r10, lr}
	
	xGrid		.req	r4
	yGrid		.req	r5
	brickNum	.req	r6
	brickType	.req	r7
	
	bl		grid_encode					@ convert coordinates to grid coords
	mov		xGrid, r0
	mov		yGrid, r1
	
	cmp		yGrid, #24					@ check if yGrid past last drawable brick area
	bgt		cib_returnFalse				@	if TRUE: set return value to FALSE and exit
	
	@ calculate brickNum on grid: brickNum = (yGrid * 15) + xGrid
	mov		r3, #15
	mul		brickNum, yGrid, r3
	add		brickNum, xGrid
	
	@ get brick type  (r0) at brickNum from brick_map
	ldr		r3, =brick_map
	ldrb	brickType, [r3, brickNum]
	sub		brickType, #48				@ adjust ASCII value to brickType value
	
	cmp		brickType, #0				@ check if brick type = clear
	beq		cib_returnFalse				@ 	if TRUE: return false
										@	else: decrement brick, redraw, and return TRUE
	sub		brickType, #1
	mov		r0, xGrid					@ pass xGrid value
	mov		r1, yGrid					@ pass yGrid value
	mov		r2, brickType				@ pass brickType
	bl		draw_brick					@ draw new brick
	
	increment_event:
	bl		incrementBlocksBroken
	bl		incrementScore
	
	break1:
	cmp		brickType, #0				@ check if new brickType is NOW 0
	bne		cib_returnTrue				@	if false: continue returning 1
										@	else do additional checks for power ups
	ldr		r3, =powerup1
	ldr		r2, [r3, #9]				@ get yCoord of powerup1
	cmp		brickNum, r2				@ check if brickNum is (powerup1)
	bleq	pup1_activate				@	if True: activate powerup 1 to start falling
	
	ldr		r3, =powerup2
	ldr		r2, [r3, #9]				@ get yCoord of powerup2
	cmp		brickNum, r2				@ check if brickNum is (powerup1)
	bleq	pup2_activate				@	if True: activate powerup 2 to start falling
	
	
	cib_returnTrue:
	mov		r0, #1						@ return TRUE and exit
	b		cib_exit
	
	cib_returnFalse:
	mov		r0, #0
		
	cib_exit:
	.unreq		xGrid
	.unreq		yGrid
	.unreq		brickNum
	.unreq		brickType
	
	b		ret

/*
 * check_is_paddle:
 *	- check if given x,y coordinate is paddle. If coord IS paddle, change angle and direction of ball
 *	Input:
 *		r0 = x coordinate
 *		r1 = y coordinate
 *	Ouput:
 *		r0 = TRUE/FALSE if brick (0 = false, 1 = true)
 */
check_is_paddle:
	push	{r4-r10, lr}
	
	xBase		.req	r4
	yBase		.req	r5
	xEnd		.req	r6
	yEnd		.req	r7
	ballAddr	.req	r8
	paddleAddr	.req	r9
	diff		.req	r10
	
	mov		xBase, r0					@ save ball x base coord
	mov		yBase, r1					@ save ball y base coord
	add		xEnd, xBase, #11			@ save ball x end coord
	add		yEnd, yBase, #11			@ save ball y end coord
	
	ldr		ballAddr, =ball_coords		@ load ball coords
	ldr		paddleAddr, =paddle_coords	@ load paddle coords
	
	ldr		r3, =#496
	cmp		yEnd, r3					@ check if bottom of ball is above top of paddle zone
	blt		cip_FALSE					@	if ball above paddle, exit
	
	add		r3, #15
	cmp		yBase, r3					@ check if top of ball is below bottom paddle zone
	bgt		cip_FALSE					@	if ball below paddle, exit
	
	ldr		r3, [paddleAddr]
	cmp		xEnd, r3					@ check if right end of ball is before left end of paddle
	blt		cip_FALSE					@	if TRUE: exit
	
	add		r3, #63
	cmp		xBase, r3					@ check if Left end of ball, is after Right end of paddle
	bgt		cip_FALSE					@	if TRUE: exit
	
	@ if method makes it here that means the ball is within the paddle zone
	
	@ first check if powerup1 (sticky paddle) is active and make paddle sticky if so
	ldr		r3, =scoreboard
	ldrb	r3, [r3, #16]				@ load powerup1 scoreboard flag
	cmp		r3, #1						@ check if powerup is on
	bne		cip_alter_ball				@	if False: continue with ball modifying
	ldr		r3, =paddle_sticky			@	else: load paddle_sticky and set flag TRUE
	mov		r1, #1
	str		r1, [r3]
	
	cip_alter_ball:
	ldr		r3, [paddleAddr]			@ load paddle x base
	add		diff, xBase, #6				@ calculate center of ball
	
	add		r3, #15
	cmp		diff, r3					@ check if center of ball less than Or equal to leftSide of paddle
	ble		cip_left_side				@	if True: send ball left at 45 angle
	add		r3, #32
	cmp		diff, r3					@	else: check if center of ball within center of paddle
	ble		cip_center					@		if True: send ball up, same horizontal, at 60 angle
										@		else: send ball right at 45 angle
	cip_right_side:
		mov		r3, #1
		strb	r3, [ballAddr, #16]			@ set ball angle to 45
		strb	r3, [ballAddr, #18]			@ set vertical direction UP
		mov		r3, #2
		strb	r3, [ballAddr, #17]			@ set horizontal direction RIGHT
		b		cip_TRUE
		
	cip_center:
		mov		r3, #1
		strb	r3, [ballAddr, #18]			@ set vertical direction UP
		mov		r3, #2
		strb	r3, [ballAddr, #16]			@ set ball angle to 60
		b		cip_TRUE
		
	cip_left_side:
		mov		r3, #1
		strb	r3, [ballAddr, #16]			@ set ball angle to 45
		strb	r3, [ballAddr, #18]			@ set vertical direction UP
		strb	r3, [ballAddr, #17]			@ set horizontal direction LEFT
	
	cip_TRUE:
		mov		r0, #1					@ return true
		b		cip_exit
	
	cip_FALSE:
		mov		r0, #0					@ return false
	
	cip_exit:
	.unreq		xBase
	.unreq		yBase
	.unreq		xEnd
	.unreq		yEnd
	.unreq		ballAddr
	.unreq		paddleAddr
	.unreq		diff
	
	b		ret

/*
 * check_is_powerup:
 *		- checks if powerup at paddle coord and enables if in contact
 */
check_is_powerup:
	push	{r4-r10, lr}
	
	paddleCoord	.req	r4
	varAddr		.req	r5
	yCoord		.req	r6

	ldr		varAddr, =paddle_coords
	ldr		paddleCoord, [varAddr]				@ load current paddle coordinate
	
	@ check if powerups visible and do stuff, otherwise skip
	cipup_check_pup1:
		ldr		varAddr, =powerup1				@ check if powerup1 visible
		ldrb	r3, [varAddr, #8]				@	if false: check powerup2
		cmp		r3, #1							@	else: check if powerup1 within paddle region
		bne		cipup_check_pup2
	
		ldr		r3, =#65
		cmp		paddleCoord, r3					@ check if paddle within left-side range of powerup1
		blt		cipup_check_pup2				@	if not, check pup2
		ldr		r3, =#159
		cmp		paddleCoord, r3					@ check if paddle within right-side range of powerup1
		bgt		cipup_check_pup2				@	if not, check pup2
	
		ldr		yCoord, [varAddr, #4]			@ load powerup yCoord
		ldr		r3, =#481
		cmp		yCoord, r3						@ check if powerup low enough
		blt		cipup_check_pup2				@	if not, check pup2
		ldr		r3, =#511
		cmp		yCoord, r3						@ check if powerup still high enough
		bgt		cipup_check_pup2				@	if not, check pup2
		
		@ enable powerup1
		bl		enable_pup1
	
	cipup_check_pup2:
		ldr		varAddr, =powerup2				@ check if powerup2 visible
		ldrb	r3, [varAddr, #8]				@	if false: skip to checking sticky paddle
		cmp		r3, #1							@	else: check if powerup1 within paddle region
		bne		cipup_exit
	
		ldr		r3, =#257
		cmp		paddleCoord, r3					@ check if paddle within left-side range of powerup2
		blt		cipup_exit						@	if not, check sticky paddle
		ldr		r3, =#351
		cmp		paddleCoord, r3					@ check if paddle within right-side range of powerup2
		bgt		cipup_exit						@	if not, check sticky paddle
	
		ldr		yCoord, [varAddr, #4]			@ load powerup yCoord
		ldr		r3, =#481
		cmp		yCoord, r3						@ check if powerup low enough
		blt		cipup_exit						@	if not, check sticky paddle
		ldr		r3, =#511
		cmp		yCoord, r3						@ check if powerup still high enough
		bgt		cipup_exit						@	if not, check sticky paddle
		
		@ enable powerup1
		bl		enable_pup2
	
	cipup_exit:
	.unreq		paddleCoord
	.unreq		varAddr
	.unreq		yCoord
	
	b	ret

/*
 * move_ball:
 *	- moves the ball in the set directions, at the set angle
 */
.global move_ball
move_ball:
	push	{r4-r10, lr}
	
	ballAddr	.req	r4
	angle		.req	r5
	
	ldr		ballAddr, =ball_coords
	ldrb	angle, [ballAddr, #16]		@ load angle
	
	cmp		angle, #1					@ check angle
	bne		mb_angle_60					@	if =2: move at angle 60 approximately (3/5)
										@	else: move at angle 45 approximately (2/5)
	mb_angle_45:
		mov		r0, #5
		bl		move_ball_horizontal
		mov		r0, #2
		bl		move_ball_vertical
		b		mb_exit

	mb_angle_60:
		mov		r0, #5
		bl		move_ball_horizontal
		mov		r0, #3
		bl		move_ball_vertical
		b		mb_exit

	mb_exit:
	.unreq		ballAddr
	.unreq		angle
	
	b		ret

	
/*
 * pup1_activate:
 *		- make powerup1 visible so it can start falling
 */
pup1_activate:
	push	{lr}
	ldr		r3, =powerup1
	mov		r1, #1
	strb	r1, [r3, #8]
	pop		{pc}
	
/*
 * pup2_activate:
 *		- make powerup2 visible so it can start falling
 */
pup2_activate:
	push	{lr}
	ldr		r3, =powerup2
	mov		r1, #1
	strb	r1, [r3, #8]
	pop		{pc}

/*
 * powerups_fall:
 *		- if either powerup is visible, make it gradually fall
 */
.global powerups_fall
powerups_fall:
	push	{r4-r10, lr}
	
	pup1		.req	r4
	pup2		.req	r5
	visible		.req	r6
	xCoord		.req	r7
	yCoord		.req	r8
	
	bl		check_is_powerup				@ check if powerups touches paddle
	
	ldr		pup1, =powerup1
	ldr		pup2, =powerup2
	
	ldrb	visible, [pup1, #8]				@ load pup1 visible flag
	cmp		visible, #1						@ check if pup1 is visible
	bne		pf_check_pup2					@	if FALSE: check pup2, else: make pup1 fall before checking pup2
	
		ldr		xCoord, [pup1]				@ load x coord
		ldr		yCoord, [pup1, #4]			@ load y coord
		add		yCoord, #1					@ increment y coord
		str		yCoord, [pup1, #4]			@ save new y coord
		mov		r0, xCoord
		mov		r1, yCoord
		mov		r2, #1						@ pass which powerup to draw
		bl		draw_powerup
	
	pf_check_pup2:
	ldrb	visible, [pup2, #8]				@ load pup1 visible flag
	cmp		visible, #1						@ check if pup1 is visible
	bne		pf_stop_fall							@	if FALSE: exit, else: make pup2 fall before exit
	
		ldr		xCoord, [pup2]				@ load x coord
		ldr		yCoord, [pup2, #4]			@ load y coord
		add		yCoord, #1					@ increment y coord
		str		yCoord, [pup2, #4]			@ save new y coord
		mov		r0, xCoord
		mov		r1, yCoord
		mov		r2, #2						@ pass which powerup to draw
		bl		draw_powerup
	
	pf_stop_fall:
		@ check if either pup has gone into lava in which case deactivate it
		mov		visible, #0
		ldr		r1, =#533					@ r1 = top of lava pit coord
		
		ldr		yCoord,	[pup1, #4]			@ check pup1
		add		yCoord, #1
		cmp		yCoord, r1					@ check if yCoord of pup1 greater than lava pit coord
		ble		pf_stop_fall_2				@		if FALSE: check pup2
		strb	visible, [pup1, #8]			@		if True: set pup1 to Not visible
		
	pf_stop_fall_2:
		ldr		yCoord,	[pup2, #4]			@ check pup2
		add		yCoord, #1
		cmp		yCoord, r1					@ check if yCoord of pup2 greater than lava pit coord
		ble		pf_exit						@		if FALSE: exit
		strb	visible, [pup2, #8]			@		if True: set pup2 to Not visible
	
	pf_exit:
	.unreq		pup1
	.unreq		pup2
	.unreq		visible
	.unreq		xCoord
	.unreq		yCoord
	
	b		ret
