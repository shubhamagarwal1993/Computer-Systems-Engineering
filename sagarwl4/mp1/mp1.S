
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
base_alive:		.long 0x0   # Array of 3 bytes, plus a padding byte
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
############################################################################
############################################################################
.globl mp1_rtc_tasklet
mp1_rtc_tasklet:
	pushl %ebp			#base pointer
	movl %esp, %ebp			#stack pointer to base pointer
	pushl %ebx			#callee saved registers 
	pushl %esi			#callee saved registers
	pushl %edi			#callee saved registers
	movl 4(%ebp), %ecx		#save arg1 to ecx

	pushl %eax			#saving registers
	pushl %ecx			#saving registers
	pushl %edx 			
	pushl %edi			#saving registers
	pushl %esi			#saving registers
#	call update_missiles		#function call
#	addl $4, %esp			#save argument
	popl %edx
	popl %ecx			#save return value
	popl %eax			#save return value
	
	pushl %eax			#saving registers
	pushl %ecx			#saving registers
	pushl %edx
	pushl %edi			#saving registers
	pushl %esi			#saving registers
	call redraw_bases		#function call	
	popl %esi
	popl %edi
	popl %edx
	popl %ecx			#save return value
	popl %eax			#save return value

	pushl %eax			#saving registers
	pushl %ecx			#saving registers
	pushl %edx
	push %edi			#saving registers
	push %esi			#saving registers
	call redraw_crosshairs		#function call
	popl %esi
	popl %edi
	popl %edx
	popl %ecx			#save return value
	popl %eax			#save return value
	
	popl %edi			#popping callee saved registers
	popl %esi			#popping callee saved registers
	popl %ebx			#popping callee saved registers
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
mp1_ioctl:
		ret


# ----------------- Functions private to this file -------------------

update_missiles:
/*
	start_loop:
		pushl %ebp			#base pointer
		movl %esp, %ebp			#stack ptr to base ptr
		
		movl mp1_missile_list, %edx	#save pointer address	
	
	
		cmpl $0, 28(%edx)		#check if exploded
		je UPDATE_COORDINATES		#not exploded goto label
	
		#####EXPLODES THEN DO THE FOLLOWING:	
		#STOP moving
		#draw explosion character
		#decrememnt exploded fld and when reach 0 rmv from list
		#free struct missile   
	
#		movl $0, VX(%edx)		#make x velocity 0 
#		movl $0, VY(%edx)		#make y velocity 0
	
#		decl EXPLODED(%edx)		#decrement this field 
#		cmpl $0, EXPLODED(%edx)		#check if 0 remove missile
#		jne end_of_loop			#go to end of loop

#		pushl %eax			#remove_missile begins 
#		pushl %ebx			#
#		pushl %edx 			#
#		pushl %edi 			#
#		pushl %esi 			#
#		call mp1_missile_remove		#remove the missile	
#		addl $4, %esp
#		popl %edx	
#		popl %eax			#remove_missile ends
#
#		###calling the explosion character
#		movl $64, C(%edx)
		jmp end_of_loop 


	UPDATE_COORDINATES:	###if not exploding then do tasks
		#1)missile out of screen then erase missile from screen and
		# remove frm lnkd list and struct missile freed wid mp1_free
		#2)reach destination or exploded
		#3)simple moving
		
	   #Task 1 
		cmpl $79, X(%edx)		#if x > 79  
		jg FREEING_MISSILE

		cmpl $0, X(%edx)		#if x < 0
		jl FREEING_MISSILE

		cmpl $24, Y(%edx)		#if y > 24
		jg FREEING_MISSILE
	
		cmpl $0, Y(%edx)		#if y < 0
		jl FREEING_MISSILE

	##????????????????##REDRAW A MISSILE HERE##????????????????###
		jmp START_TASK2
 
	FREEING_MISSILE:
		pushl %edx
		call mp1_redraw_missile
		popl %edx
		

START_TASK2:
	   #Task 2 
		cmpl $0, EXPLODED(%edx)		#ifmissile exploding
		jnbe TASK2_FOLLOWUP		#go to label in end
		
		movl X(%edx), %ebx		#copy to temp reg
		cmpl %ebx, DEST_X(%edx)		#if X coord not reached dest
		jne TASK2_FOLLOWUP		#go to label in end 
	
		movl Y(%edx), %ebx		#copy to temp reg
		cmpl %ebx, DEST_Y(%edx)		#if Y coord not reached dest
		jne TASK2_FOLLOWUP
	
	##????????????????##REDRAW A MISSILE HERE##????????????????###
		jmp START_TASK3			#if not expl and not dest
		
	TASK2_FOLLOWUP:
		
		pushl %eax			#pass %eax to store ret val
		pushl %edx			#this is the arg
	##########do we have to push something else#########and so pop too
		call missile_explode 
		popl %edx			#pointer returned
		popl %eax			#we get the ret val here
		
		cmpl $0, %eax			#check ret val of %eax
		je TEMP_LABEL			#temp label ends next line
	
		call mp1_notify_user		#given function to call
						#no arg were past
	TEMP_LABEL:				#if %eax=0 then do nothing
					 		
		decl EXPLODED(%edx)		#decrement exploded field
		
		cmpl $0, EXPLODED(%edx)		#		
		jne TEMP_LABEL_TASK2 
	
		pushl %eax			#if explosion char is 0
		pushl %edx			#then we call label	
		call mp1_redraw_missile		#not too sure about what 
		popl %edx			#to push and what to pop
		popl %eax			#especiallty %edx
		jmp TEMP_LABEL_TASK2a

	TEMP_LABEL_TASK2:

#???????######	jne DRAW THE EXPLOSION CHAR	#if expld not 0 then draw
###MURALI SAID USE 	movl $64, C(%edx)
		
	TEMP_LABEL_TASK2a:
		jmp START_TASK3
	
START_TASK3:
     #Task 3
	##if sceen pos has changed then draw blank and redraw new missile
	##in new position or else just redraw missile as it might not be der
		


	######task 3 gets over here				


	end_of_loop:			#done with work
		jmp start_loop
#do we have to pop ebp 
*/
		ret	 


	 
redraw_bases:
	
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

redraw_crosshairs:

	pushl %ebp
	movl %esp, %ebp
	
	push %edi
	push %esi
	push %ebx

	movb $43, %cl
	movl crosshairs_x, %eax
	movl crosshairs_y, %ebx
	imull $2, %eax
	imull $160, %ebx
	addl %ebx, %eax

	call mp1_poke

	popl %ebx
	popl %esi
	popl %edi
	popl %ebp

	ret

mp1_ioctl_startgame:
		ret

mp1_ioctl_addmissile:
		ret

mp1_ioctl_movexhairs:
		ret

mp1_ioctl_getstatus:
		ret

mp1_ioctl_endgame:
		ret


#####This is a helper function written by me #####
mp1_missile_remove:
/*
	#erase missile from screen
	#remove missile from linked list
	#struct missile freed with mp1_free
		
	FREEING_MISSILE:
	#erase from screen
	#free from linked list
	#c ll mp1_free
	
		movb $127, %cl
		movl X(%edx), %ebx
		movl Y(%edx), %eax
		imul $160, %ebx		
		imul $2, %eax		
		addl %ebx, %eax		

		 
		 pushl %eax
		 pushl %ebx
		 pushl %ecx
		 pushl %edx
		 pushl %edi
		 pushl %esi
		 call mp1_poke
		 popl %edx
		 popl %ecx
		 popl %ebp
		 popl %eax


		 pushl %eax
		 pushl %ebx
		 pushl %ecx
		 pushl %edx
		 pushl %edi
		 pushl %esi
		 call mp1_missile_remove
		 addl $4, %esp
		 popl %edx
		 popl %ecx
		 popl %ebp
		 popl %eax
		
		 pushl %eax
		 pushl %ebx
		 pushl %ecx
		 pushl %edx
		 pushl %edi
		 pushl %esi
		 call mp1_free
		 addl $4, %esp
		 popl %edx
		 popl %ecx
		 popl %ebp
		 popl %eax
*/
	ret

mp1_redraw_missile:
		ret
