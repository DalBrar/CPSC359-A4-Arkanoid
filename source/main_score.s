@ CPSC 359 Assignment 4 - Arkanoid
@		- this file contains all scoreboard related subroutines
@ Written by: Dalbir Brar
@ Student ID: 002 968 97

@ Static messages section
.section    .text

@ Code section


/*
 * initScore:
 *		- Initializes graphics to retrieve frame buffer pointer, screen width and height.
 */
.global initScore
initScore:
	push	{r4-r10, lr}				@ remember calling system's return position
	
	scrAddr		.req	r4
	
	ldr		scrAddr, =scoreboard		@ load scoreboard address
	
	mov		r0, #0
	
	str		r0, [scrAddr]				@ set score to 0
	str		r0, [scrAddr, #12]			@ set blocks broken to 0
	strb	r0, [scrAddr, #16]			@ set Powerup 1 to 0
	strb	r0, [scrAddr, #17]			@ set Powerup 2 to 0
	
	mov		r0, #3
	str		r0, [scrAddr, #4]			@ set lives to 3
	
	bl		countBlockTotal				@ initialize total number of blocks to break
	bl		displayScoreboard
	
	.unreq		scrAddr
	
	b		ret

/*
 * displayScoreboard:
 *		- displays the current score, lives, and active power ups
 */
.global displayScoreboard
displayScoreboard:
	push	{r4-r10, lr}
	
	scrAddr		.req	r4
	score		.req	r5
	lives		.req	r6
	pup1		.req	r7
	pup2		.req	r8
	
	ldr		scrAddr, =scoreboard
	ldr		score, [scrAddr]					@ load score
	ldr		lives, [scrAddr, #4]				@ load lives
	ldrb	pup1, [scrAddr, #16]				@ load power up 1
	ldrb	pup2, [scrAddr, #17]				@ load power up 2
	
	@ display score
	mov		r0, score
	bl		displayScore
	
	@ display lvies
	mov		r0, lives
	bl		displayLives
	
	@ clear powerups from scoreboard
	ldr		r0, =#443
	mov		r1, #0
	mov		r2,	#32
	mov		r3, #48
	bl		clear_img
	
	@ display powerup 1 if active
	cmp		pup1, #1
	bleq	displayPup1
	
	@ display powerup 2 if active
	cmp		pup2, #1
	bleq	displayPup2
	
	.unreq		scrAddr
	.unreq		score
	.unreq		lives
	.unreq		pup1
	.unreq		pup2
	
	b		ret

/*
 * displayScore:
 *		- displays the given score
 *	Input:
 *		r0 = score
 */
displayScore:
	push	{r4-r10, lr}
	
	score		.req	r4
	ones		.req	r5
	tens		.req	r6
	huns		.req	r7
	thos		.req	r8
	
	mov		score, r0							@ save score
	ldr		r0, =#9999
	cmp		score, r0							@ check if score greater than 9999
	movgt	score, r0							@	if TRUE: set score to 9999
	
	mov		ones, #0							@ initialize ones digit to 0
	mov		tens, #0							@ initialize tens digit to 0
	mov		huns, #0							@ initialize hundreds digit to 0
	mov		thos, #0							@ initialize thousands digit to 0
	
	@ set thousands digit
	ds_thos:
		ldr		r0, =#1000
		cmp		score, r0							@ check if score >= 1000
		addge	thos, #1							@	if TRUE: increment thousands digit
		subge	score, r0							@			 and decrement score by 1000
		bge		ds_thos								@			 then test again
	
	@ set hundreds digit
	ds_huns:
		mov		r0, #100
		cmp		score, r0							@ check if score >= 100
		addge	huns, #1							@	if TRUE: increment hundreds digit
		subge	score, r0							@			 and decrement score by 100
		bge		ds_huns								@			 then test again
	
	@ set tens digit
	ds_tens:
		mov		r0, #10
		cmp		score, r0							@ check if score >= 10
		addge	tens, #1							@	if TRUE: increment tens digit
		subge	score, r0							@			 and decrement score by 10
		bge		ds_tens								@			 then test again
	
	@ set ones digit
		mov		ones, score							@ set ones digit
		
	mov		r0, thos							@ pass digit
	mov		r1, #128							@ pass x coord
	mov		r2, #8								@ pass y coord
	bl		draw_number
		
	mov		r0, huns							@ pass digit
	mov		r1, #153							@ pass x coord
	mov		r2, #8								@ pass y coord
	bl		draw_number
		
	mov		r0, tens							@ pass digit
	mov		r1, #178							@ pass x coord
	mov		r2, #8								@ pass y coord
	bl		draw_number
		
	mov		r0, ones							@ pass digit
	mov		r1, #203							@ pass x coord
	mov		r2, #8								@ pass y coord
	bl		draw_number
	
	.unreq		score
	.unreq		ones
	.unreq		tens
	.unreq		huns
	.unreq		thos
	
	b		ret

/*
 * displayLives:
 *		- displays the input lives
 *	Input:
 *		r0 = lives
 */
displayLives:
	push	{lr}
	
	cmp		r0, #9						@ check if lives greater than 9
	movgt	r0, #9						@	if TRUE: set lives to 9
	mov		r1, #340							@ pass x coord
	mov		r2, #8								@ pass y coord
	bl		draw_number
	
	pop		{pc}

/*
 * displayPup1:
 *		- displays powerup 1 in the scoreboard while it's active
 */
displayPup1:
	push	{lr}
	
	ldr		r3, =drawImgAddr			@ load stored image address
	ldr		r2, =gfx_pup1				@ load address of powerup1 image
	str		r2, [r3]					@ save address of image to stored image address
	
	mov		r0, #443					@ pass xCoord
	mov		r1, #5						@ pass yCoord
	mov		r2, #32						@ pass width
	mov		r3, #16						@ pass Height
	bl		draw_img_at					@ draw powerup
	
	pop		{pc}

/*
 * displayPup2:
 *		- displays powerup 2 in the scoreboard while it's active
 */
displayPup2:
	push	{lr}
	
	ldr		r3, =drawImgAddr			@ load stored image address
	ldr		r2, =gfx_pup2				@ load address of powerup2 image
	str		r2, [r3]					@ save address of image to stored image address
	
	mov		r0, #443					@ pass xCoord
	mov		r1, #27						@ pass yCoord
	mov		r2, #32						@ pass width
	mov		r3, #16						@ pass Height
	bl		draw_img_at					@ draw powerup
	
	pop		{pc}


/*
 * countBlockTotal:
 *		- sets the total number of blocks to break
 */
countBlockTotal:
	push	{lr}
	
	mov		r2, #0					@ initialize brickNum to 0
	mov		r0, #0					@ initialize total number of bricks to 0
	
	cbt_loop:
		ldr		r3, =brick_map_init	@ load brick map
		ldrb	r1, [r3, r2]		@ r1 = brickType
		sub		r1, #48				@ adjust ASCII value to brickType value
			
		cmp		r1, #0				@ check brickType value
		movlt	r1, #0				@ if < 0 set brickType to 0 <Failsafe incase user enters invalid characters>
		
		add		r0, r1				@ add bricktype to total number of bricks
		
		add		r2, #1				@ increment brickNum
		
		ldr		r3, =#375
		cmp		r2, r3				@ check if brickNum less than total number of bricks in map
		blt		cbt_loop			@	if TRUE: loop back to next brick
	
	ldr		r3, =scoreboard		@ load scoreboard
	str		r0, [r3, #8]		@ save total number of blocks to total number of blocks to break
	
	pop		{pc}

/*
 * incrementBlocksBroken:
 *		- adds 1 to the total number of blocks broken
 */
.global incrementBlocksBroken
incrementBlocksBroken:
	push	{lr}
	ldr		r3, =scoreboard			@ load scoreboard
	ldr		r0, [r3, #12]			@ load total blocks broken
	add		r0, #1					@ increment by 1
	str		r0, [r3, #12]			@ save total blocks broken
	pop		{pc}

/*
 * incrementScore:
 *		- increments score based on (2 * (2 + LivesLeft))
 */
.global incrementScore
incrementScore:
	push	{lr}
	ldr		r3, =scoreboard			@ load scoreboard
	ldr		r0, [r3]				@ load score
	ldr		r1, [r3, #4]			@ load lives

	add		r1, #2					@ r1 = lives + 2
	lsl		r1, #1					@ r1 *= 2
	add		r0, r1					@ increment score by r1
	str		r0, [r3]				@ save score
	pop		{pc}

@ Data section
.section    .data

.global scoreboard
scoreboard:
	.int	0		@ 0 = score (gets incremented when ball breaks blocks or decremented when lose lives)
	.int	3		@ 4 = lives
	.int	0		@ 8 = Total number of blocks to break (gets incremented when bricks are loaded)
	.int	0		@ 12= Total number of blocks broken (gets incremented as ball breaks bricks)
	.byte	0		@ 16= Power up 1 (0= off, 1= On)
	.byte	0		@ 17= Power up 2 (0= off, 1= On)

.align