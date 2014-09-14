
# mp1.S - missile-command version
# Good luck, and have fun!

.data
	
    # Constants for accessing the fields of a struct missile, 
    # struct missile is defined in rtc.h and mp1.h

	NEXT 	  = 0
	X	  = 4
	Y	  = 8
	VX	  = 12
	VY	  = 16
	DEST_X	  = 20
	DEST_Y	  = 24
	EXPLODED  = 28
	C	  = 32

    # Character to draw for an explosion - '@'

	EXPLOSION = 64


# Data shared between this file and rtc.c helper functions

# This '.globl' directive makes these symbols visible externally
.globl mp1_missile_list, base_alive, mp1_score

mp1_missile_list:	.long 0x0	# Head of list pointer
base_alive:		.long 0x0	# Array of 3 bytes, plus a padding byte
mp1_score:		.long 0x0	# Player's current score


# Data private to this  file

base_pic:     	    .string "/^^^\\"	# Picture of a live base
dead_base_pic: 	    .string "xxxxx"	# Picture of a dead base
crosshairs_x:		.long 0x0	# X-position of the crosshairs
crosshairs_y:		.long 0x0	# Y-position of the crosshairs

.text

# void mp1_poke(void);
# You can use this function to write to video memory.
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX

mp1_poke:
		movl    vmem_base_addr(,1),%edx
		movb    %cl,(%edx,%eax,1)
		ret

#   ----------------- Exported functions ---------------------

# void mp1_rtc_tasklet(unsigned long garbage);
# Performs three tasks:
#	(1) updates the list of missiles (implement this in update_missiles,
#           below, and call it from here).
#	(2) Redraw the bases - they may have been overwritten with missiles
#	(3) Redraw the crosshairs - it may have been overwritten with missiles
# Inputs   : none
# Outputs  : none
# Registers: Standard C calling convention

.globl mp1_rtc_tasklet
mp1_rtc_tasklet:
	
	movl mp1_missile_list,%edx
	
	pushl %ebp				#base pointer
	movl %esp, %ebp			#stack pointer to base pointer
	pushl %ebx				#callee saved registers 
	pushl %esi				#callee saved registers
	pushl %edi				#callee saved registers
	movl 4(%ebp), %ecx		#save arg1 to ecx

	pushl %eax				#saving registers
	pushl %ecx				#saving registers
	pushl %edx 			
	pushl %edi				#saving registers
	pushl %esi				#saving registers
	call redraw_cities
	popl %esi
	popl %edi
	popl %edx
	popl %ecx				#save return value
	popl %eax

	popl %edi
	popl %esi
	popl %ebx
	leave
	ret


# int mp1_ioctl(unsigned long arg, unsigned int cmd)
# The dispatch function for the MP1 ioctls - should use the cmd argument
# and a jumptable to execute one of the specific ioctls implemented below.
# Inputs   : unsigned long arg - parameter to the mp1_ioctl_....
#          : unsigned int cmd  - specifies which mp1_ioctl_... function 
#          :                     to execute
# Outputs  : Returns an integer - depends on which ioctl() function is called
# Registers: Standard C calling convention

.globl mp1_ioctl
	jump_table:
	.long mp1_ioctl_startgame, mp1_ioctl_addmissile, mp1_ioctl_movexhairs, mp1_ioctl_getstatus, mp1_ioctl_endgame
mp1_ioctl:

	movl 8(%esp), %ebx		#save 'cmd' in EBX

	jmp *jump_table(,%ebx,4)		
	
	cmpl $0, %ebx
	jl finish
	cmpl $4,%ebx
	jg finish
	jmp *jump_table(,%ebx,4)
	jmp end_jump_table			

	finish:
	movl $-1, %eax

	end_jump_table:
	ret

# ----------------- Functions private to this file -------------------

update_missiles:
	ret


redraw_cities:
#offset 1 = 2928 -> 3568
#offset 2 = 6128 -> 6768
#offset 3 = 9328 -> 9968

	pushl %ebp
	movl %esp, %ebp
	
 	xorl %eax, %eax
	xorl %edi, %edi
	xorl %esi, %esi
	xorl %edx, %edx
	addl $3876,%edx
	#offset=(24*2*80)+(18*2)=3876

	movl $base_pic, %ebx
next_base:
shiftx:
	movb (%ebx), %cl

	movl %edx, %eax
	
	push %edx	
	call mp1_poke
	popl %edx	
	addl $1, %edi
	addl $2, %edx
	addl $1, %ebx
	cmpl $5, %edi
	jl shiftx
	movl $base_pic, %ebx
	addl $1, %esi
	addl $32, %edx
	xorl %edi,%edi
	cmpl $3, %esi
	jl next_base

	popl %ebp
	ret


delete_missile:
	ret

mp1_ioctl_startgame:
	#do we need to use ebp and esp
	#initialize all the variables 
	#offset = (160*12)+(2*40) = 2000
	#	xorl %ecx, %ecx
	#	addl $2000, %ebx
		
	movl $0x0, mp1_missile_list
	movl $0x0, base_alive
	movl $0x0, mp1_score

	movl $40, crosshairs_x
	movl $12, crosshairs_y
	ret
		
mp1_ioctl_addmissile:

	movl 4(%esp), %esi			#EBX contains arg

	push %esi
	push %edi
	push %ebx

	push %edx
	push $33
	call mp1_malloc				#free the current cell 
	popl %edx
	xorl %edx, %edx			#pointer to space just freed
	
	push $33
	push %esi
	push %eax

	#unsigned long mp1_copy_from_user(*to,*from,n)

	call mp1_copy_from_user			#copy user missile struct 
	
	movl 4(%esp), %edi		#contains whether valid transfer
	popl %eax
	popl %esi
	popl %ebx

	xorl %ebx,%ebx 				#clear esi
	xorl %esi, %esi

	cmpl $0,%eax				#check if copy was not valid
	jg invalid

#valid
	xorl %edi, %edi
	xorl %ebx,%ebx

	push %edx
	movl NEXT(%edx), %esi

	movl %eax,NEXT(%edx)
	movl %esi,NEXT(%eax)

	xorl %edx,%edx
	popl %edx

	jmp fin
		
invalid:
	xorl %edi,%edi
	push %eax
	call mp1_free				#free the current cell 
	pop %eax
	addl $-1,%edi
	jmp fin

fin:
	popl %ebx
	popl %edx
	popl %edi
	popl %esi

	leave
	ret


mp1_ioctl_movexhairs:
	##draw a blank in place of x and y
	##position the crosshairs	

	xorl %eax, %eax
	xorl %ebx, %ebx
	movl crosshairs_x, %eax
	movl crosshairs_y, %ebx

	imull $2, %eax
	imull $160, %ebx
	
	addl %ebx, %eax

	mov $32, %cl

	call mp1_poke

	movl 4(%esp), %ebx

	addw %bx, crosshairs_x
	movw $79, %ax

	shrl $16, %ebx
	addw %bx, crosshairs_y

	cmpw $0, crosshairs_x
	jl X_LO

	cmpw $79, crosshairs_x
	jg X_HI

	cmpw $0, crosshairs_y
	jl Y_LO

	cmpw $24, crosshairs_y
	jg Y_HI
	jmp draw_crosshairs

	
	X_LO:
	movl $0, crosshairs_x
	jmp draw_crosshairs

	X_HI:
	movw $79, crosshairs_x
	jmp draw_crosshairs

	Y_LO:
	movw $0, crosshairs_y
	jmp draw_crosshairs

	Y_HI:
	movw $24, crosshairs_y
	jmp draw_crosshairs
	
	draw_crosshairs:
#draw the new crosshairs
	xorl %eax, %eax
	xorl %ebx, %ebx
	movl crosshairs_x, %eax
	movl crosshairs_y, %ebx

	imull $2, %eax
	imull $160, %ebx	
	addl %ebx, %eax
	
	movb $43, %cl
	call mp1_poke

	ret
	
mp1_ioctl_getstatus:
		ret

mp1_ioctl_endgame:
		ret
