@ CPSC 359 Assignment 4 - Arkanoid
@	- this file controls printing of graphics
@ Written by: Dalbir Brar
@ Student ID: 002 968 97

@ Static messages section
.section    .text
gpu_init:	.asciz	"\nInitializing Graphics...\n"
gpu_done:	.asciz	"Graphics Initialized.\n\n"
endOfcon:	.align

@ Code section

/*
 * initGraphics:
 *		- Initializes graphics to retrieve frame buffer pointer, screen width and height.
 */
.global initGraphics
initGraphics:
	push	{r4-r10, lr}				@ remember calling system's return position

	frameBase	.req	r4
	baseWidth	.req	r5
	baseHeight	.req	r6
	
	ldr		r0, =gpu_init
	bl		printf

	@ ask for frame buffer information
	ldr 	r0, =frameBufferInfo		@ frame buffer information structure
	bl		initFbInfo

	@ adjust and store offsets
	ldr		frameBase, =frameBufferInfo
	ldr		baseWidth, [frameBase, #4]		@ load width
	ldr		baseHeight, [frameBase, #8]		@ load height
	
	lsr		baseWidth, #1					@ width = (width/2) - 241
	sub		baseWidth, baseWidth, #241
	cmp		baseWidth, #0					@ if width < 0:
	movlt	baseWidth, #0					@		then set baseWidth = 0
	str		baseWidth, [frameBase, #12]		@ store width offset
	
	ldr		r3,	=#551						@ height = height-551
	sub		baseHeight, baseHeight, r3
	cmp		baseHeight, #0					@ if height < 0:
	movlt	baseHeight, #0					@		then set baseHeight = 0
	str		baseHeight, [frameBase, #16]	@ store height offset
	
	ldr		r0, =gpu_done
	bl		printf

	.unreq	frameBase
	.unreq	baseWidth
	.unreq	baseHeight
	
	b		ret

/*
 * DrawPixel:
 *	Inputs:
 *		r0 - x
 *		r1 - y
 *		r2 - colour
 */
DrawPixel:
	push	{r4-r10, lr}

	offset		.req	r4

	ldr		r5, =frameBufferInfo	

	@ offset = (y * width) + x
	ldr		r3, [r5, #4]		@ r3 = width
	mul		r1, r3
	add		offset,	r0, r1
	
	@ offset *= 4 (32 bits per pixel/8 = 4 bytes per pixel)
	lsl		offset, #2

	@ store the colour (word) at frame buffer pointer + offset
	ldr		r0, [r5]			@ r0 = frame buffer pointer
	tst		r2, #0xff000000		@ test for transparency
	strne	r2, [r0, offset]	@ skip if transparent

	b		ret

/*
 * draw_img_full:
 *	- draws full image
 *	input:
 *		0 = start menu
 *		1 = quit screen
 *		2 = game background
 */
.global draw_img_full
draw_img_full:
	push	{r4-r10, lr}
	
	input		.req	r0
	frameBase	.req	r3
	imgBase		.req	r4
	baseWidth	.req	r5
	baseHeight	.req	r6
	x_r			.req	r7
	y_r			.req	r8
	pixelOffset	.req	r9
		
	cmp		input, #0							@ check input
	beq		dif_load_startmenu					@ if = 0, draw start menu
	
	cmp		input, #1							@ if = 1, draw quit screen
	beq		dif_load_quit
	
	ldr		imgBase, =gfx_bgd					@ else draw game background
	b		dif_draw

dif_load_startmenu:
	ldr		imgBase, =gfx_startmenu
	b		dif_draw
	
dif_load_quit:
	ldr		imgBase, =gfx_quitscreen

dif_draw:
	ldr		frameBase, =frameBufferInfo
	
	ldr		baseWidth, [frameBase, #12]			@ load width offset
	ldr		baseHeight, [frameBase, #16]		@ load height offset
	
	mov		pixelOffset, #0						@ set pixelOffset to 0
	
	mov		y_r,	baseHeight
	
	dif_outerloop:
		mov		x_r, baseWidth
		
		dif_innerloop:
			mov		r0,	x_r
			mov		r1, y_r
			ldr		r2, [imgBase, pixelOffset]
			bl		DrawPixel
			
			add		pixelOffset, #4				@ incriment pixelOffset
			
			ldr		r1, =#479
			add		r0, baseWidth, r1
			cmp		x_r, r0						@ compare x with x_offset+480 (bgd width)
			addlt	x_r, #1						@ if less than width of image, increment x and loop
			blt		dif_innerloop
			
		ldr		r3, =#549
		add		r0, baseHeight, r3
		cmp		y_r, r0						@ compare y with y_offset+550 (bgd height)
		addlt	y_r, #1						@ if less than height of image, increment y and loop
		blt		dif_outerloop	
		
	.unreq		input
	.unreq		frameBase
	.unreq		imgBase
	.unreq		baseWidth
	.unreq		baseHeight
	.unreq		x_r
	.unreq		y_r
	.unreq		pixelOffset
	
	b		ret

/*
 * draw_img_at:
 *	- draws specific image at input location
 *	input:
 *		r0 = x base coord
 *		r1 = y base coord
 *		r2 = image width
 *		r3 = image height
 */
.global draw_img_at
draw_img_at:
	push	{r4-r10, lr}
	
	xBase_r		.req	r4
	yBase_r		.req	r5
	xEnd_r		.req	r6
	yEnd_r		.req	r7
	imgBase		.req	r8
	temp_r		.req	r9
	pixelOffset	.req	r10
	
	@ store input values
	mov		xBase_r, r0
	mov		yBase_r, r1
	mov		xEnd_r, r2
	mov		yEnd_r, r3
	
	ldr		imgBase, =drawImgAddr				@ load address of image to draw
	ldr		imgBase, [imgBase]
	
	ldr		r3, =frameBufferInfo
	ldr		r0, [r3, #12]					@ load width offset
	ldr		r1, [r3, #16]					@ load height offset
	
	@ adjust input values for offsets
	add		xBase_r, r0
	add		yBase_r, r1
	add		xEnd_r, xBase_r
	add		yEnd_r, yBase_r
	sub		xEnd_r, #1
	sub		yEnd_r, #1
	
	mov		pixelOffset, #0						@ set pixelOffset to 0
	
	dia_outerloop:
		mov		temp_r, xBase_r					@ set xCurrent
		
		dia_innerloop:
			mov		r0,	temp_r
			mov		r1, yBase_r
			ldr		r2, [imgBase, pixelOffset]
			
			bl		DrawPixel
			
			add		pixelOffset, #4				@ incriment pixelOffset
			
			cmp		temp_r, xEnd_r				@ compare xCurrent with xEnd_r
			addlt	temp_r, #1					@ if less than: increment xCurrent and loop
			blt		dia_innerloop

		cmp		yBase_r, yEnd_r				@ compare yCurrent with yEnd_r
		addlt	yBase_r, #1					@ if less than: increment yCurrent and loop
		blt		dia_outerloop	

	.unreq		xBase_r
	.unreq		yBase_r
	.unreq		xEnd_r
	.unreq		yEnd_r
	.unreq		imgBase
	.unreq		temp_r
	.unreq		pixelOffset
	
	b		ret

/*
 * clear_img:
 *	- clears image at input location
 *	input:
 *		r0 = x base coord
 *		r1 = y base coord
 *		r2 = image width
 *		r3 = image height
 */
.global clear_img
clear_img:
	push	{r4-r10, lr}
	
	xBase_r		.req	r4
	yBase_r		.req	r5
	xEnd_r		.req	r6
	yEnd_r		.req	r7
	imgBase		.req	r8
	temp_r		.req	r9
	pixelOffset	.req	r10
	
	@ store input values
	mov		xBase_r, r0
	mov		yBase_r, r1
	mov		xEnd_r, r2
	mov		yEnd_r, r3
	
	@ calculate pixel offset for new line increment and store in variable
	ldr		r0, =#480						@ r0 = imageWidth
	sub		r1, r0, r2						@ r1 = imageWidth - clearWidth
	lsl		r1, #2							@ r1 *= 4
	ldr		r0, =clearimg_nl
	str		r1, [r0]						@ store r1 in variable
	
	
	@ initialize pixelOffset, pixelOffset = ((imageWidth * yBase_r) + xBase_r) * 4
	ldr		r0, =#480
	mul		pixelOffset, r0, yBase_r
	add		pixelOffset, xBase_r
	lsl		pixelOffset, #2
	
	ldr		imgBase, =gfx_bgd				@ load address of image background to clear
	
	ldr		temp_r, =frameBufferInfo
	ldr		r0, [temp_r, #12]				@ load width offset
	ldr		r1, [temp_r, #16]				@ load height offset
	
	@ adjust input values for offsets
	add		xBase_r, r0
	add		yBase_r, r1
	add		xEnd_r, xBase_r
	add		yEnd_r, yBase_r
	sub		xEnd_r, #1
	sub		yEnd_r, #1
		
	ci_outerloop:
		mov		temp_r, xBase_r				@ set xCurrent
		
		ci_innerloop:
			mov		r0,	temp_r					@ initialize and call DrawPixel
			mov		r1, yBase_r
			ldr		r2, [imgBase, pixelOffset]
			bl		DrawPixel
			
			add		pixelOffset, #4				@ incriment pixelOffset for next pixel
			
			cmp		temp_r, xEnd_r				@ compare xCurrent with xEnd_r
			addlt	temp_r, #1					@ if less than: increment xCurrent and loop
			blt		ci_innerloop

		ldr		r0, =clearimg_nl
		ldr		r0, [r0]					@ load increment new line variable value
		add		pixelOffset, r0				@ increment pixelOffset for next line
		
		cmp		yBase_r, yEnd_r				@ compare yCurrent with yEnd_r
		addlt	yBase_r, #1					@ if less than: increment yCurrent and loop
		blt		ci_outerloop	

	.unreq		xBase_r
	.unreq		yBase_r
	.unreq		xEnd_r
	.unreq		yEnd_r
	.unreq		imgBase
	.unreq		temp_r
	.unreq		pixelOffset
	
	b		ret

/*
 * draw_smenu_start:
 *	- draws start menu start selected and pass on inputs to draw_img_at
 *	input:
 *		r0 = x base coord
 *		r1 = y base coord
 */
.global draw_smenu_start
draw_smenu_start:
	push	{r4-r10, lr}
	
	storedAddr	.req	r4
	imgToLoad	.req	r5
	
	ldr		storedAddr, =drawImgAddr			@ load stored image address
	ldr		imgToLoad, =gfx_startm_start		@ load image address to store
	str		imgToLoad, [storedAddr]				@ store image address at stored img address
	
	mov		r2, #128							@ set img Width
	mov		r3, #112							@ set img Height
	bl		draw_img_at
	
	.unreq		storedAddr
	.unreq		imgToLoad
	
	b		ret

/*
 * draw_smenu_quit:
 *	- draws start menu quit selected and pass on inputs to draw_img_at
 *	input:
 *		r0 = x base coord
 *		r1 = y base coord
 */
.global draw_smenu_quit
draw_smenu_quit:
	push	{r4-r10, lr}
	
	storedAddr	.req	r4
	imgToLoad	.req	r5
	
	ldr		storedAddr, =drawImgAddr			@ load stored image address
	ldr		imgToLoad, =gfx_startm_quit			@ load image address to store
	str		imgToLoad, [storedAddr]				@ store image address at stored img address
	
	mov		r2, #128							@ set img Width
	mov		r3, #112							@ set img Height
	bl		draw_img_at
	
	.unreq		storedAddr
	.unreq		imgToLoad
	
	b		ret

/*
 * draw_pmenu:
 *	- draws pause menu title
 *	input:
 *		r0 = which colour frame (0 - 9) to draw
 */
.global draw_pmenu
draw_pmenu:
	push	{lr}
	
	@ check which frame and load frame image accordingly:
	cmp		r0, #0
	ldreq	r2, =gfx_pmenu_title0
	
	cmp		r0, #1
	ldreq	r2, =gfx_pmenu_title1
	
	cmp		r0, #2
	ldreq	r2, =gfx_pmenu_title2
	
	cmp		r0, #3
	ldreq	r2, =gfx_pmenu_title3
	
	cmp		r0, #4
	ldreq	r2, =gfx_pmenu_title4
	
	cmp		r0, #5
	ldreq	r2, =gfx_pmenu_title5
	
	cmp		r0, #6
	ldreq	r2, =gfx_pmenu_title6
	
	cmp		r0, #7
	ldreq	r2, =gfx_pmenu_title7
	
	cmp		r0, #8
	ldreq	r2, =gfx_pmenu_title8
	
	cmp		r0, #9
	ldreq	r2, =gfx_pmenu_title9
	
	@ save frame to stored image address
	ldr		r3, =drawImgAddr				@ r3 = stored image address
	str		r2, [r3]
	
	mov		r0, #96							@ set x coord
	mov		r1, #160						@ set y coord
	mov		r2, #288						@ set img Width
	mov		r3, #64							@ set img Height
	bl		draw_img_at

	pop		{pc}

/*
 * draw_pmenu_options:
 *	- draws pause menu selected option
 *	input:
 *		r0 = choice number (0 = Resume, 1 = Restart, 2 = Main Menu)
 */
.global draw_pmenu_options
draw_pmenu_options:
	push	{lr}
	
	@ check which option selected and load option image accordingly:
	cmp		r0, #0
	ldreq	r2, =gfx_pmenu_option0
	
	cmp		r0, #1
	ldreq	r2, =gfx_pmenu_option1
	
	cmp		r0, #2
	ldreq	r2, =gfx_pmenu_option2
	
	@ save frame to stored image address
	ldr		r3, =drawImgAddr				@ r3 = stored image address
	str		r2, [r3]
	
	mov		r0, #112						@ set x coord
	mov		r1, #336						@ set y coord
	mov		r2, #256						@ set img Width
	mov		r3, #160						@ set img Height
	bl		draw_img_at

	pop		{pc}

/*
 * draw_paddle:
 *	- draws paddle at specific x location
 *	input:
 *		r0 = x coord
 */
.global draw_paddle
draw_paddle:
	push	{r4-r10, lr}
	
	storedAddr	.req	r4
	paddleCoord	.req	r5
	imgToLoad	.req	r6
	
	ldr		storedAddr, =drawImgAddr			@ load stored image address
	ldr		paddleCoord, =paddle_coords			@ load address of paddle_coords
	str		r0, [paddleCoord]					@ store new x coord in paddle_coords
	
	@ clear old paddle
	ldr		imgToLoad, =gfx_bgd					@ load image address to store
	str		imgToLoad, [storedAddr]				@ store image address at stored img address
	ldr		r0, [paddleCoord, #4]
	ldr		r1, =#496
	mov		r2, #64
	mov		r3, #16
	bl		clear_img
	
	@ draw new paddle
	ldr		imgToLoad, =gfx_paddle				@ load image address to store
	str		imgToLoad, [storedAddr]				@ store image address at stored img address
	ldr		r0, [paddleCoord]
	ldr		r1, =#496
	mov		r2, #64
	mov		r3, #16
	bl		draw_img_at
	
	@ update old coord with new coord
	ldr		r0, [paddleCoord]
	str		r0, [paddleCoord, #4]
	
	.unreq		storedAddr
	.unreq		paddleCoord
	.unreq		imgToLoad
	
	b		ret
	
/*
 * draw_ball:
 *	- draws ball at specific x,y location
 *	input:
 *		r0 = ball x coord
 *		r1 = ball y coord
 */
.global draw_ball
draw_ball:
	push	{r4-r10, lr}
	
	storedAddr	.req	r4
	ballCoords	.req	r5
	imgToLoad	.req	r6
	
	ldr		storedAddr, =drawImgAddr			@ load stored image address
	ldr		ballCoords, =ball_coords			@ load address of paddle_coords
	str		r0, [ballCoords]					@ store new x coord in ball_coords
	str		r1, [ballCoords, #4]				@ store new y coord in ball_coords
	
	@ clear old ball
	ldr		imgToLoad, =gfx_bgd					@ load image address to store
	str		imgToLoad, [storedAddr]				@ store image address at stored img address
	ldr		r0, [ballCoords, #8]
	ldr		r1, [ballCoords, #12]
	mov		r2, #12
	mov		r3, #12
	bl		clear_img
	
	@ draw new ball
	ldr		imgToLoad, =gfx_ball				@ load image address to store
	str		imgToLoad, [storedAddr]				@ store image address at stored img address
	ldr		r0, [ballCoords]
	ldr		r1, [ballCoords, #4]
	mov		r2, #12
	mov		r3, #12
	bl		draw_img_at
	
	@ update old coords with new coords
	ldr		r0, [ballCoords]
	ldr		r1, [ballCoords, #4]
	str		r0, [ballCoords, #8]
	str		r1, [ballCoords, #12]
	
	.unreq		storedAddr
	.unreq		ballCoords
	.unreq		imgToLoad
	
	b		ret

/*
 * draw_brick:
 *	- draws brick at specific x,y grid location and saves brick location and type on brick_map
 *	- NOTE: grid is a WxH of 32x16 for bricks accross the graphic area of the game
 *	input:
 *		r0 = ball x grid coord
 *		r1 = ball y grid coord
 *		r2 = type of brick (0 = clear, 1 = gray, 2 = yellow, 3 = red)
 */
.global draw_brick
draw_brick:
	push	{r4-r10, lr}

	storedAddr	.req	r4
	xCoord		.req	r5
	yCoord		.req	r6
	brickType	.req	r7
	brickNum	.req	r8
	
	ldr		storedAddr, =drawImgAddr			@ load stored image address
	mov		xCoord, r0							@ store x grid coord
	mov		yCoord, r1							@ store y grid coord
	mov		brickType, r2						@ store brickType
	
	cmp		brickType, #1						@ check brickType
	bgt		db_thickbrick						@	if > 1, check thick bricks
	blt		db_clear							@	if < 1, clear brick
	ldr		r3, =gfx_brick1						@	else load gray brick to draw
	str		r3, [storedAddr]
	b		db_draw								@ 	then draw brick
	
	db_thickbrick:
		cmp		brickType, #2						@ check brickType
		bgt		db_brick3							@ 	if > 2, goto load brick3
		ldr		r3, =gfx_brick2						@	else load yellow brick to draw
		str		r3, [storedAddr]
		b		db_draw								@ 	then draw brick
	
	db_brick3:
		ldr		r3, =gfx_brick3						@	load red brick to draw
		str		r3, [storedAddr]					@ 	then draw brick
		mov		brickType, #3						@ failsafe incase user enters number greater than 3 as bricktype
		
	db_draw:
		mov		r0, xCoord							@ x grid coord
		mov		r1, yCoord							@ y grid coord
		bl		grid_decode							@ convert grid coords to base coords
		mov		r2, #32								@ brick width
		mov		r3, #16								@ brick height
		bl		draw_img_at							@ draw brick
		b		db_save_brick						@ then continue
		
	db_clear:
		ldr		r3, =gfx_bgd						@ load image-to-clear-with address to store
		str		r3, [storedAddr]					@ store image address at stored img address
		mov		r0, xCoord							@ x grid coord
		mov		r1, yCoord							@ y grid coord
		bl		grid_decode							@ convert grid coords to base coords
		mov		r2, #32								@ brick width
		mov		r3, #16								@ brick height
		bl		clear_img							@ clear brick
	
	db_save_brick:
		ldr		storedAddr, =brick_map				@ load brick_map address to save brick state
		
		@ calculate brick number: bruckNum = (15 * yCoord) + xCoord
		mov		brickNum, yCoord					@ brickNum = yCoord
		lsl		brickNum, #4						@ brickNum = yCoord * 16
		sub		brickNum, yCoord					@ brickNum = yCoord * 15
		add		brickNum, xCoord					@ brickNum += xCoord
		
		add		brickType, #48						@ adjust brickType value to ASCII
		
		strb	brickType, [storedAddr, brickNum]	@ store brickType at brick number
	
	.unreq		storedAddr
	.unreq		xCoord
	.unreq		yCoord
	.unreq		brickType
	.unreq		brickNum
	
	b		ret

/*
 * draw_lava:
 *	- draws lava at bottom of game
 */
.global draw_lava
draw_lava:
	push	{lr}
	
	@ save lava address to stored image address
	ldr		r2, =gfx_lava
	ldr		r3, =drawImgAddr				@ r3 = stored image address
	str		r2, [r3]
	
	mov		r0, #32							@ set x coord
	mov		r1, #533						@ set y coord
	mov		r2, #416						@ set img Width
	mov		r3, #16							@ set img Height
	bl		draw_img_at

	pop		{pc}

/*
 * draw_winlose:
 *	- draws victory or game over message
 *	Input:
 *		r0 = win/lose (0 = win, 1 = lose)
 */
.global draw_winlose
draw_winlose:
	push	{lr}
	
	cmp		r0, #0							@ check if input = 0
	ldreq	r2, =gfx_win					@	if TRUE: load win graphic
	ldrne	r2, =gfx_lose					@	else: load lose graphic
	
	ldr		r3, =drawImgAddr				@ r3 = stored image address
	str		r2, [r3]						@ set graphic to draw
	
	mov		r0, #0							@ set x coord
	mov		r1, #160						@ set y coord
	mov		r2, #480						@ set img Width
	mov		r3, #80							@ set img Height
	bl		draw_img_at

	pop		{pc}

/*
 * draw_number:
 *	- draws a number at given x,y coodinates
 *	Input:
 *		r0 = digit
 *		r1 = x Coordinate
 *		r2 = y Coordinate
 */
.global draw_number
draw_number:
	push		{r4-r10, lr}
	
	digit		.req	r4
	xCoord		.req	r6
	yCoord		.req	r7
	storedAddr	.req	r8
	
	mov		digit, r0						@ save digit
	mov		xCoord, r1						@ save x coord
	mov		yCoord, r2						@ save y coord
	ldr		storedAddr, =drawImgAddr		@ load stored image address

	cmp		digit, #9
	ldreq	r3, =gfx_num9
	streq	r3, [storedAddr]
	beq		dn_draw
	
	cmp		digit, #8
	ldreq	r3, =gfx_num8
	streq	r3, [storedAddr]
	beq		dn_draw
	
	cmp		digit, #7
	ldreq	r3, =gfx_num7
	streq	r3, [storedAddr]
	beq		dn_draw
	
	cmp		digit, #6
	ldreq	r3, =gfx_num6
	streq	r3, [storedAddr]
	beq		dn_draw
	
	cmp		digit, #5
	ldreq	r3, =gfx_num5
	streq	r3, [storedAddr]
	beq		dn_draw
	
	cmp		digit, #4
	ldreq	r3, =gfx_num4
	streq	r3, [storedAddr]
	beq		dn_draw
	
	cmp		digit, #3
	ldreq	r3, =gfx_num3
	streq	r3, [storedAddr]
	beq		dn_draw
	
	cmp		digit, #2
	ldreq	r3, =gfx_num2
	streq	r3, [storedAddr]
	beq		dn_draw
	
	cmp		digit, #1
	ldreq	r3, =gfx_num1
	streq	r3, [storedAddr]
	beq		dn_draw
	
	cmp		digit, #0
	ldreq	r3, =gfx_num0
	streq	r3, [storedAddr]
	
	dn_draw:
		@ first clear previous number
		mov		r0, xCoord
		mov		r1, yCoord
		mov		r2,	#25
		mov		r3, #32
		bl		clear_img
		
		@ then draw new number
		mov		r0, xCoord
		mov		r1, yCoord
		mov		r2, #25
		mov		r3, #32
		bl		draw_img_at
	
	.unreq		digit
	.unreq		xCoord
	.unreq		yCoord
	.unreq		storedAddr

	b		ret

/*
 * draw_powerup:
 *		- draws given powerup at given x,y coordinates, redraws bricks as it falls
 *	Input:
 *		r0 = x coord
 *		r1 = y coord
 *		r2 = powerup type (1 = pup1, 2 = pup2)
 */
.global draw_powerup
draw_powerup:
	push		{r4-r10, lr}
	
	xCoord		.req	r4
	yCoord		.req	r5
	pupNum		.req	r6
	brickAdr	.req	r7
	brickNum	.req	r8
	brickType	.req	r9
	storedAddr	.req	r10
	
	
	mov		xCoord, r0
	mov		yCoord, r1
	mov		pupNum, r2
	ldr		brickAdr, =brick_map
	ldr		storedAddr, =drawImgAddr			@ load stored image address
	
	@ get grid values of current coordinates
	mov		r0, xCoord
	mov		r1, yCoord
	sub		r1, #1							@ decrement y coord for previous coordinate
	bl		grid_encode
	
	@ check if yGrid is past bricks map area
	cmp		r1, #25
	bge		dpup_clear						@	if True: skip re-drawing brick and just clear background
	
	@ get brickNum from grid coordinates
	mov		r3, #15
	mul		brickNum, r1, r3
	add		brickNum, r0					@ brickNum = (yGrid * 15) + xGrid
	
	@ get brickType
	ldr		r3, =brick_map
	ldrb	brickType, [r3, brickNum]
	sub		brickType, #48					@ adjust ASCII value to brickType value
	
	@ redraw passed over brick
	@ get grid values of current coordinates again to pass xGrid n yGrid values to r0 n r1
	mov		r0, xCoord
	mov		r1, yCoord
	sub		r1, #1							@ decrement y coord for previous coordinate
	bl		grid_encode
	mov		r2, brickType					@ pass brickType
	bl		draw_brick						@ draw brick
	b		dpup_draw
	
	dpup_clear:
		mov		r0, xCoord
		mov		r1, yCoord
		sub		r1, #1
		mov		r2, #32
		mov		r3, #16
		bl		clear_img
	
	dpup_draw:
	@ now draw new location of powerup
	cmp		pupNum, #1						@ check if powerup 1
	bne		draw_pup2						@	If False: draw pup2, else draw pup1
	
	draw_pup1:
		ldr		pupNum, =gfx_pup1			@ load image address to store
		str		pupNum, [storedAddr]		@ store image address at stored img address
		b		dpup_exit
	
	draw_pup2:
		ldr		pupNum, =gfx_pup2			@ load image address to store
		str		pupNum, [storedAddr]		@ store image address at stored img address
	
	dpup_exit:
		mov		r0, xCoord
		mov		r1, yCoord
		mov		r2, #32
		mov		r3, #16
		bl		draw_img_at
		
	.unreq		xCoord
	.unreq		yCoord
	.unreq		pupNum
	.unreq		brickAdr
	.unreq		brickNum
	.unreq		brickType
	.unreq		storedAddr
	
	b			ret

	
/*
 * grid_decode:
 *	- converts x,y grid coordinates into x,y base coordinates
 *	input:
 *		r0 = x grid coord
 *		r1 = y grid coord
 *	output:
 *		r0 = x base coord
 *		r1 = y base coord
 */
.global grid_decode
grid_decode:
	push	{lr}
	lsl		r0, #5			@ x = x * 32
	lsl		r1, #4			@ y = y * 16
	pop		{pc}

/*
 * grid_encode:
 *	- converts x,y base coordinates into x,y grid coordinates
 *	input:
 *		r0 = x base coord
 *		r1 = y base coord
 *	output:
 *		r0 = x grid coord
 *		r1 = y grid coord
 */
.global grid_encode
grid_encode:
	push	{lr}
	
	mov		r2, #0				@ initialize xGrid
	mov		r3, #0				@ initialize yGrid
	
	ge_loop_x:
		cmp		r0, #31				@ compare xBase with 31
		subhi	r0, #32				@ subtract 32 if xBase is higher than 31
		addhi	r2, #1				@ increment xGrid by 1
		bhi		ge_loop_x			@ loop until xBase is less than 32
		
	ge_loop_y:
		cmp		r1, #15				@ compare yBase with 15
		subhi	r1, #16				@ subtract 16 if yBase is higher than 15
		addhi	r3, #1				@ increment yGrid by 1
		bhi		ge_loop_y			@ loop until yBase is less than 16
		
	mov		r0, r2				@ return xGrid
	mov		r1, r3				@ return yGrid
	
	pop		{pc}


@ Data section
.section .data
.align

.globl frameBufferInfo
frameBufferInfo:
	.int	0		@  0= frame buffer pointer
	.int	0		@  4= screen width
	.int	0		@  8= screen height
	.int	0		@ 12= width offset
	.int	0		@ 16= height offset

.global drawImgAddr
drawImgAddr:
	.int	0		@ address of image to draw
	
clearimg_nl:
	.int	0		@ temp variable to store new line pixel increment

.align 4
font:		.incbin	"font.bin"

.end
