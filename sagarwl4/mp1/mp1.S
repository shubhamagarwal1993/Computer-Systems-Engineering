
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
	
	pushl %ebp			#base pointer
	movl %esp, %ebp		#stack ptr to base ptr
	subl $4, %esp			#making space 

	movl mp1_missile_list, %ecx	#save pointer address	
	
   linked_list_loop:
	cmpl $0, EXPLODED(%ecx)		#check if exploded
	je UPDATE_COORDINATES		#not exploded goto label

		
	#exploded then not move & draw explosion character & decrememnt this field & when reaches 0 remove missile from list and free struct missile   
	
	movl $0, VX(%ecx)		#make x velocity 0 
	movl $0, VY(%ecx)		#make y velocity 0
	decl EXPLODED(%ecx)		#decrement this field 
	
	cmpl $0, EXPLODED(%ecx)		#check if 0 remove missile
	jne skip_next			#random label

	push %eax			#remove_missile begins 
	push %ecx
	push %edi
	push %esi
	call missile_remove		#remove the missile	
	addl $4, %esp
	popl %ecx	
	popl %eax			#remove_missile ends

  skip_next:
	#draw explosion character	
	movl $64, C(%ecx)		#dawing

	jmp end_of_loop
	
	
  UPDATE_COORDINATES:		###if not exploding then update x and y
	LOWER_X_LIMIT = 0
	HIGHER_X_LIMIT = 79
	LOWER_Y_LIMIT = 0
	HIGHER_Y_LIMIT = 24
	# 1)missile goes out of screen then erase missile from screen and remove from linked list and struct missile freed with mp1_free
	# 2)reach destination or exploded
	# 3)simple moving
		
	#Task 1 
		cmpl $79, X(%ecx)		#if x > 79  
		jg FREEING_MISSILE	#missile removed from list
		cmpl $0, X(%ecx)		#if x < 0
		jl FREEING_MISSILE	#missile removed from list
		cmpl $24, Y(%ecx)		#if y > 24
		jg FREEING_MISSILE	#missile removes from list
		cmpl $0, Y(%ecx)		#if y < 0
		jl FREEING_MISSILE	#missile removes from list

	#Task 2 
		####checking for dest_x and x and dest_y and y
		movl X(%ecx), %ebx		#copy temp
		cmpl %ebx, DEST_X(%ecx)		#if X coord reached dest
		jne temp_skip			#skip if not matches 
	
		movl Y(%ecx), %ebx		#copy temp
		cmpl %ebx, DEST_Y(%ecx)		#if Y coord reached dest
		jne temp_skip

		
	#%eax will have non-zero value if any other thing is exploded
		pushl %eax
		pushl %ecx
		pushl %edi
		pushl %esi
		call missile_explode 
		popl %ecx
		popl %eax
		
		cmpl $0, %eax
		je temp_skip
		push %eax
		push %ecx
		push %edi
		push %esi
		call mp1_notify_user
		addl $4, %esp
		popl %ecx
		popl %eax

	temp_skip:
		decl EXPLODED(%ecx)
		cmpl $0, EXPLODED(%ecx)
		jne skip_2
		
		push %eax
		push %ecx
		push %edi
		push %esi
		call FREEING_MISSILE
		popl %ecx
		popl %eax

	skip_2:
		#set C to explosion character
		movl $64, C(%ecx)
		
		

     #Task 3


	pushl %ebp
	movl %esp, %ebp
	movl X(%ecx), %esi			#copy X temp
	movl Y(%ecx), %edi			#copy Y temp
	mul $160, %esi				#X=X*2*80
	mul $2, %edi				#Y=Y*2
	add %edi, %esi				#now %esi has the offset 
	movl %esi, %eax				#draw at new position
	mov  $127, %cl
	pushl %edx				#caller saved so we push it
	call mp1_poke				#finds starting addr of vid
	popl %edx				#pop after function call
	popl %ebp				
	
	movl X(%ecx), %ebx			
	add %bx, X(%ecx) 			#add lower 16 bits
	movl Y(%ecx), %ebx
	add %bx, Y(%ecx)			#add lower 16 bits 	

	pushl %ebp
	movl %esp, %ebp
	movl X(%ecx), %esi			#copy X temp
	movl Y(%ecx), %edi			#copy Y temp
	mull $160, %ebx				#X=X*2*80
	mull $2, %edx				#Y=Y*2
	add %ebx, %edx				#now %esi has the offset 
	movl %edx, %eax				#draw at new position
	mov  C(%ecx), %cl
	push %edx				#caller saved so we push it
	call mp1_poke				#finds starting addr of vid
	popl %edx				#pop after function call
	popl %ebp				


	ret

FREEING_MISSILE:
	#erase from screen
	#free from linked list
	#call mp1_free
	
	movl X(%ecx), %esi			#copy X temp
	movl Y(%ecx), %edi			#copy Y temp
	mull $160, %esi				#X=X*2*80
	mull $2, %edi				#Y=Y*2
	add %edi, %esi				#now %esi has the offset 

	pushl %ebp
	movl %esp, %ebp
	movl %esi, %eax			#draw at (18,24) to (22,24)
	mov  $127, %cl
	pushl %edx				#caller saved so we push it
	call mp1_poke				#finds starting addr of vid
	popl %edx				#pop after function call
	popl %ebp				
	


	push %eax
	push %ecx
	push %edi
	push %esi
	call mp1_missile_remove			#remove from linked list
	addl $4, %esp
	popl %ecx
	popl %eax
	
	pushl %ecx 
	pushl %edi
	pushl %esi
	call mp1_free				#struct missile freed
	addl $4, %esp
	popl %ecx
	popl %eax

	ret

redraw_bases:
	movl $5, %esi				#put a variable in esi 
	#offset=(24*2*80)+(18*2)=3876
	

	loop1:
	pushl %ebp
	movl %esp, %ebp
	movl $3876, %eax			#draw at (18,24) to (22,24)
#	mov  $base_pic, %cl
	subl $1, %esi				#decrease variable
	addl $4, %eax
	pushl %edx				#caller saved so we push it
	call mp1_poke				#finds starting addr of vid
	popl %edx				#pop after function call
	popl %ebp				
	cmpl $0, %esi
	jg loop1	  

	#offset=(24*2*80)+(38*2)=3916
	pushl %ebp
	movl %esp, %ebp
	movl $3916, %eax			#draw at (38,24) to (42,24)
	movb $42, %cl
	pushl %edx				#caller saved so we push it
	call mp1_poke				#finds starting addr of vid
	popl %edx				#pop after function call
	popl %ebp

	#offset=(24*2*80)+(58*2)=3956
	pushl %ebp
	movl %esp, %ebp
	movl $3956, %eax			#draw at (58,24) to (62,24)
	movb $42, %cl
	pushl %edx				#caller saved so we push it
	call mp1_poke				#finds starting addr of vid
	popl %edx				#pop after function call
	popl %ebp
	
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
