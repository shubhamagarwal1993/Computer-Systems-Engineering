
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
	pushl %ebp		#base pointer
	movl %esp, %ebp		#stack pointer to base pointer
	pushl %ebx		#callee saved registers 
	pushl %esi		#callee saved registers
	pushl %edi		#callee saved registers
	movl 4(%ebp), %ecx	#save arg1 to ecx

	push %eax		#saving registers
	push %ecx		#saving registers
	push %edi		#saving registers
	push %esi		#saving registers
	call update_missiles	#function call
	addl $4, %esp		#save argument
	popl %ecx		#save return value
	popl %eax		#save return value
	
	push %eax		#saving registers
	push %ecx		#saving registers
	push %edi		#saving registers
	push %esi		#saving registers
	call redraw_bases	#function call	
	addl $4, %esp		#save argument
	popl %ecx		#save return value
	popl %eax		#save return value

	push %eax		#saving registers
	push %ecx		#saving registers
	push %edi		#saving registers
	push %esi		#saving registers
	call redraw_crosshairs	#function call
	addl $4, %esp		#save argument
	popl %ecx		#save return value
	popl %eax		#save return value
	
	popl %edi		#popping callee saved registers
	popl %esi		#popping callee saved registers
	popl %ebx		#popping callee saved registers
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
	
	loop:
		pushl %ebp			#base pointer
		pushl %esp, %ebp		#stack ptr to base ptr
####do we need to save an argument here	movl 4(%ebp), %eax		

		movl mp1_missile_list, %ecx	#save pointer address	
		cmpl $0, EXPLODED(%ecx)		#check if exploded
		je UPDATE_COORDINATES		#not exploded goto label
########################################	
	#exploded then not move & draw explosion character & decrememnt this field & when reaches 0 remove missile from list and free struct missile   
	
		movl $0, VX(%ecx)		#make x velocity 0 
		movl $0, VY(%ecx)		#make y velocity 0
	#draw explosion character
		movl $64, C(%ecx)		#draw explosion char	
	

		subl $1, EXPLODED(%ecx)		#decrement this field
		cmpl $0, EXPLODED(%ecx)
		
		push %eax			#remove_missile begins 
		push %ecx
		push %edi
		push %esi
		call missile_remove		#remove the missile	
		addl $4, %esp
		popl %ecx	
		popl %eax			#remove_missile ends

	#go to end of loop		

		

	#draw explosion character 


UPDATE_COORDINATES:		###if not exploding then update x and y
	LOWER_X_LIMIT = 0
	HIGHER_X_LIMIT = 79
	LOWER_Y_LIMIT = 0
	HIGHER_Y_LIMIT = 24
	# 1)missile goes out of screen then erase missile from screen and remove from linked list and struct missile freed with mp1_free
	# 2)reach destination or exploded
	# 3)simple moving
		
	#Task 1 
		jg $79, X(%ecx)		#if x > 79  
		jmp FREEING_MISSILE	#missile removed from list
		jl $0, X(%ecx)		#if x < 0
		jmp FREEING_MISSILE	#missile removed from list
		jg $24, Y(%ecx)		#if y > 24
		jmp FREEING_MISSILE	#missile removes from list
		jl $0, Y(%ecx)		#if y < 0
		jmp FREEING_MISSILE	#missile removes from list

	#Task 2 
		jg $0, EXPLODED(%ecx)		#if missile exploding
		pushl %ecx			#pass argument
		call missile_explode		#given function
		popl %ecx			#get the return value
		
	#%eax will have non-zero value if any other thing is exploded  	
		decl EXPLODED(%ecx)		#dec field for this missile
		cmpl $0, EXPLODED(%ecx)		#if field reaches 0 rem mis
		jmp FREEING_MISSILE		#missile removes completely

#########if exploded field is not 0 then it shld be drawn to screen with the explosion character##########		
		
	####checking for dest_x and x 
		cmpl X(%ecx), DEST_X(%ecx)	#if X coord reached dest
		je CHECK_Y_DEST_Y_coord		#check if Y coord rch dest
		cmpl $0, %esi			#if y coord reached dest
	#%eax will have non-zero value if any other thing is exploded
		decl EXPLODED(%ecx)		#dec field for this missile
		cmpl $0, EXPLODED(%ecx)		#if field reaches 0 rem mis
		jmp FREEING MISSILE		#missile removes completely
######HAVE TO CHECK IMPLEMANTATION OF TASK 2 AGAIN##########
			
	#Task 3
		movl VX(%ecx), %esi		#save X vel in temp
		addl %esi, X(%ecx)		#new X = X + VX
		mvol VY(%ecx), %esi		#save Y vel in temp
		addl %esi, Y(%ecx)		#new Y = Y + VY	
	#DO WE HAVE TO DRAW SOMETHING HERE


FREEING MISSILE:
	mp1_missile_remove			#remove from linked list
	mp1_free				#struct missile freed
	ret
CHECK_Y_DEST_Y_COORD:				#check y and y_dest coord
	cmpl Y(%ecx), DEST_Y(%ecx)		#if Y coord reached dest
	movl $0, %esi				#make %esi 0 for equal coord
	ret

	ret

redraw_bases:
	#offset=(24*2*80)+(18*2)=3876
	movl $3876, %eax
	movl 3876(%eax), %cl			#draw at (18,24) to (22,24)
	pushl %edx				#caller saved so we push it
	call mp1_poke				#finds starting addr of vid
	popl %edx				#pop after function call
				#all other registers are callee saved
	#offset=(24*2*80)+(38*2)=3916
	movl 3916(%eax), %cl			#draw at (38,24) to (42,24)
	pushl %edx				#caller saved so we push it
	call mp1_poke				#finds starting addr of vid
	popl %edx				#pop after function call

	#offset=(24*2*80)+(58*2)=3956
	movl 3956(%eax), %cl			#draw at (58,24) to (62,24)
	pushl %edx				#caller saved so we push it
	call mp1_poke				#finds starting addr of vid
	popl %edx				#pop after function call
	
	ret

redraw_crosshairs:
	
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
	#erase missile from screen
	#remove missile from linked list
	#struct missile freed with mp1_free
		ret
