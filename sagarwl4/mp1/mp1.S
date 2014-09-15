
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

	UPPER_X_SCREEN_COORD = 79
	LOWER_X_SCREEN_COORD = 0
	UPPER_Y_SCREEN_COORD = 24
	LOWER_Y_SCREEN_COORD = 0
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

		pushl %ebp				#base pointer
		movl %esp, %ebp			#stack pointer to base pointer

		movl mp1_missile_list,%edx

		pushl %eax				#saving registers
		pushl %ebx 				#saving registers
		pushl %ecx				#saving registers
		pushl %edx 				#saving registers
		pushl %edi				#saving registers
		pushl %esi				#saving registers
		call update_missiles
		popl %esi 				#saving registers
		popl %edi 				#saving registers
		popl %edx 				#saving registers
		popl %ecx				#save return value
		popl %ebx 				#saving registers
		popl %eax 				#saving registers

		pushl %eax				#saving registers
		pushl %ebx 				#saving registers
		pushl %ecx				#saving registers
		pushl %edx 				#saving registers
		pushl %edi				#saving registers
		pushl %esi				#saving registers
		call redraw_bases
		popl %esi 				#saving registers
		popl %edi 				#saving registers
		popl %edx 				#saving registers
		popl %ecx				#saving registers
		popl %ebx 				#saving registers
		popl %eax 				#saving registers

		leave
		ret


# ----------------- Functions private to this file -------------------

update_missiles:
		pushl %ebp 				#setup base pointer
		movl %esp, %ebp 		#setup stack pointer

		#check if missile list is empty 
		cmpl $0, mp1_missile_list
		je exit_update
		
		movl mp1_missile_list, %edx 	#save pointer address	
		

	start_loop:
		#check weather missile is currently exploding	
		cmpl $0, EXPLODED(%edx)	#check if exploded
		je UPDATE_COORDINATES	#not then update coords
	
		#####EXPLODES THEN DO THE FOLLOWING:	
		#stop moving
		#draw explosion character
		#check for neighborhood explosion
		#decrememnt exploded fld till reaches 0 & rmv from list
		#free struct missile by calling function    
	
		movl $0, VX(%edx)		#make x velocity 0 
		movl $0, VY(%edx)		#make y velocity 0
	
		#checking for neighborhood explosion
		pushl %edx 				#saving pointer
		call missile_explode 	#checks neighborhood explosion
		popl %edx 				#getting back pointer
		cmpl $0, %eax 			#check ret value
		je dont_notify 			#if eax 0 no surround explosions
		pushl %edx 				#saving pointer
		#call mp1_notify_user 	#tell about neighborhood explosions
		popl %edx 				#getting back pointer
	
	dont_notify:	
		decl EXPLODED(%edx)		#decrement field to reach 0 
		cmpl $0, EXPLODED(%edx)	#check if 0 remove missile
		#je delete_missile		#go to end of loop
		jmp end_of_loop

		movl X(%edx), %eax 		#start calculating offset
		movl Y(%edx), %ebx 		#start calculating offset
		sarl $16,%eax 			#right shift to get proper number
		sarl $16,%ebx 			#right shift to get proper number
		imull $2, %eax 			#2 is for bytes per cell
		imull $160, %ebx		#2*80 is for byte & displacement
		addl %ebx, %eax 		#%eax holds total displacement
		movb C(%edx), %cl 		#cl holds the display ASCII character
		pushl %edx 				#saving pointer
		call mp1_poke 			#printing on screen
		popl %edx 				#get back pointer
		jmp end_of_loop 		#done then exit 

	UPDATE_COORDINATES:	###if not exploding then do tasks
		#1)missile out of screen then erase missile from screen and
		# remove frm lnkd list and struct missile freed wid mp1_free
		#2)reach destination or exploded
		#3)simple moving
		
	   #Task 1 
		movl X(%edx), %eax 		#start calculating offset		
		movl Y(%edx), %ebx  	#start calculating offset  
		sarl $16,%eax 			#right shift to get proper number
		sarl $16,%ebx 			#right shift to get proper number

		cmpl $79, X(%edx)		#if x > 79  
		jl missile_remove 		#check if out of screen
		cmpl $0, X(%edx)		#if x < 0
		jl missile_remove 		#check if out of screen
		cmpl $24, Y(%edx)		#if y > 24
		jl missile_remove 		#check if out of screen	
		cmpl $0, Y(%edx)		#if y < 0
		jl missile_remove 		#check if out of screen

		imull $2, %eax  		#2 is for bytes per cell
		imull $160, %ebx		#2*80 is for byte & displacement
		addl %ebx, %eax 		#%eax holds total displacement
		movb C(%edx), %cl 		#cl holds the display ASCII character
		pushl %edx 				#saving pointer
		call mp1_poke			#printing on screen
		popl %edx 				#get back pointer
		
		#1. Erase the variable
		#2. Call rmv_missile
		#3. Call mp1_free


START_TASK2:
	   #Task 2 
		#CASE 2
		# If X == DEST_X and Y==DEST_Y, then call missile_exploded
		movl X(%edx), %ebx			#storing in temp reg 
		sarl $16, %ebx 				#right shift to get number
		cmpl %ebx, DEST_X(%edx) 	#If DEST_X == X	
		jne exploding				#if x not match then skip
		
		movl Y(%edx), %ebx 			#storing in temp reg
		sarl $16, %ebx 				#right shift to get number
		cmpl %ebx, DEST_Y(%edx)		#If DEST_Y == Y
		jne exploding				#if x not match then skip
		
		pushl %edx 					#saving pointer
		call missile_explode 		#printing on screen
		popl %edx 					#get back pointer

		cmpl $0, %eax 				#
		je exploding 				#

		pushl %eax 					#save registers
		pushl %ecx 					#save registers
		pushl %edx 					#save registers
		#call mp1_notify_user 		#
		popl %edx 					#save registers 
		popl %ecx 					#save registers
		popl %eax 					#save registers

exploding:
		movl EXPLODED(%edx),%ebx 	#
		cmpl $0, EXPLODED(%edx) 	#
		je START_TASK3 				#
		#decrement EXPLODED 		#decrement this field
		subl $1,EXPLODED(%edx) 		#
		movl EXPLODED(%edx),%ebx 	#
		#movl $0,EXPLODED(%edx) 	#
		cmpl $0, EXPLODED(%edx) 	#
		jne skip2 					#
			#   If 0, call free_missile
		jmp missile_remove 			#
skip2:	
		#draw the EXPLOSION character

		movl X(%edx), %eax 			#
		movl Y(%edx), %ebx 			#
		sarl $16,%eax 				#
		sarl $16,%ebx 		 		#
		imull $2, %eax 				#X*2
		imull $160, %ebx			#Y*160
		addl %ebx, %eax 			#
		movb $64, %cl 				#
		pushl %edx 					#
		call mp1_poke 				#
		popl %edx 					#
		jmp end_of_loop 			#
		
	
	
START_TASK3:

	
     #Task 3
	##if sceen pos has changed then draw blank and redraw new missile
	##in new position or else just redraw missile as it might not be der
		
	#Erase the old missile from screen
		movl Y(%edx), %ebx 			#
		movl X(%edx), %eax 			#
		sarl $16, %eax 				#
		sarl $16, %ebx 				#
		imul $160, %ebx		 		#
		imul $2, %eax	 			#	
		addl %ebx, %eax		 		#
		movb $32, %cl 				#
		#pushl %ebp 				#
		#movl %esp, %ebp 			#
		pushl %edx 					#
		call mp1_poke 				#
		popl %edx 					#
		#popl %ebp 					#
		
		# Calculate new screen position
		movl VY(%edx), %eax 		#
		movl VX(%edx), %ebx 		#
		addl %ebx, X(%edx) 			#
		addl %eax, Y(%edx) 			#
		
		# Redraw the missile
		movl Y(%edx), %ebx 			#
		movl X(%edx), %eax 			#
		sarl $16, %eax 				#
		sarl $16, %ebx 			 	#
		imul $160, %ebx				# EAX holds X*160
		imul $2, %eax				# EAX holds Y*2
		addl %ebx, %eax				# Offset in EAX
		movb C(%edx), %cl 			#
		#pushl %ebp 				#
		#movl %esp, %ebp 			#
		pushl %edx 					#
		call mp1_poke 				#
		popl %edx 					#
		
	FREEING_MISSILE:
		#pushl %edx 				#
		#call delete_missile	 	#
		#popl %edx 					#
		

		end_of_loop:
		#movl %edx,%edi 			#
		movl NEXT(%edx),%esi 		#
		cmpl $0,%esi 				#
		je exit_update 				#
		movl %esi,%edx 				#
		xorl %esi,%esi 				#
		jmp start_loop 				#

		exit_update:
		leave
		ret



redraw_bases:
		#offset=(24*2*80)+(18*2)=3876

		pushl %ebp 					#
		movl %esp, %ebp 			#
		
	 	xorl %eax, %eax 			#
		xorl %edi, %edi 			#
		xorl %esi, %esi 			#
		xorl %edx, %edx 			#
		addl $3876,%edx 			#

		movl $base_pic, %ebx 		#
	next_base: 				
	shiftx:
		movb (%ebx), %cl 			#

		movl %edx, %eax 			#
								
		push %edx	 				#
		call mp1_poke 				#
		popl %edx	 				#
		addl $1, %edi 				#
		addl $2, %edx 				#
		addl $1, %ebx 				#
		cmpl $5, %edi 				#
		jl shiftx
		movl $base_pic, %ebx 		#
		addl $1, %esi 				#
		addl $32, %edx 				#
		xorl %edi,%edi 				#
		cmpl $3, %esi 				#
		jl next_base 				#

		popl %ebp 					#
		ret 						#



############ tasklet gets over here


#######################\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
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


		movl 8(%esp), %ebx			#save 'cmd' in EBX

		jmp *jump_table(,%ebx,4)	#calling from jumptable	

		cmpl $0, %ebx 				#if arg less than 0
		jl finish 					#return -1
		cmpl $4,%ebx 				#if arg greater than 4
		jg finish 					#return -1
		jmp *jump_table(,%ebx,4) 	#jump to corresopnding arg
		jmp end_jump_table			#ret

		finish:						#temp Label
		movl $-1, %eax 				#retrun -1

		end_jump_table:				#temp Label
		ret 						#leave function


###########################////////////////////////////////////////////////////////////////////////////////////////////////////////////
mp1_ioctl_startgame:
				#initialize all the variables 
				#offset = (160*12)+(2*40) = 2000
				
		movl $0x0, mp1_missile_list #given above
		movl $0x0, base_alive 		#given above
		movl $0x0, mp1_score 		#given above

		movl $40, crosshairs_x 		#set in middle of screen
		movl $12, crosshairs_y 		#set in middle of screen


		ret
		
mp1_ioctl_addmissile:
	/*
			int mp1 ioctl addmissile (struct missile* user missile);
			This ioctl must add a new missile to the game. The parameter is a pointer to a struct missile in user space. This
			function needs to copy the user’s missile into a dynamically allocated buffer in kernel space. If either the dynamic
			memory allocation (see “Allocating and Freeing Memory” below) or the data copy (see “Moving data to/from the
			kernel”) fails, this function should return -1. If it does fail, it should be sure to free any memory it has allocated before
			returning. If it succeeds, it should add the new missile into the linked list and return 0.
		*/
		
		
		movl 4(%esp), %esi			#esi gets *from arg

		push %esi 					#save esi
		push %edi 					#save edi
		push %ebx 					#save ebx

		#movl $33,%ebx
		push %edx 					#save edx
		#push %ebx 					#push size of dynamic memory
		push $33
		call mp1_malloc				#assign dynamic memory 
		popl %edx 					#temporarily store 33
		xorl %edx,%edx 				#clear 33
		popl %edx 					#retrieve original stack pointer
		#now, eax is the 33bit space i created

		push $33 					#push size of dynamic memory
		push %esi 					#push *from arg
		push %eax					#push *to arg
		#unsigned long mp1_copy_from_user(*to,*from,n)
		call mp1_copy_from_user							#copy user missile struct 
		#eax contains whether valid transfer
		popl %edi 					#retrieve *to arg and store in edi
		popl %esi 					#retrieve *from arg
		popl %ebx 					#temporarily store 33
		xorl %ebx,%ebx 				#clear 33
		xorl %esi,%esi 				#clear esi (previously stored *from)

		cmpl $0,%eax				#check if copy was not valid
		jg invalid
		
		#valid
		movl mp1_missile_list,%ebx  #
		movl %ebx,(%edi) 			#
		movl %edi,mp1_missile_list 	#
		#movl %edi,%edx 			#

		jmp fin 					#jump to end

		invalid:
		#xorl %edi,%edi
		push %edi 					#pass address of new dynamic space
		call mp1_free				#free the current cell 
		pop %edi 					#pop address arg
		addl $-1,%eax 				#put -1 in eax to return
		jmp fin 					#jump to end

		fin:
		#PRECAUTION: complete callee saves
		popl %ebx
		popl %edx
		popl %edi
		popl %esi

		leave
		ret




		
################################################################################?\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
mp1_ioctl_movexhairs:
	
	##draw a blank in place of x and y
	##position the crosshairs	

	xorl %eax, %eax 				#clear for use
	xorl %ebx, %ebx 	 			#clear for use
	movl crosshairs_x, %eax 		#temp store x
	movl crosshairs_y, %ebx 		#temp store y
	imull $2, %eax 					#offset - 2 bytes
	imull $160, %ebx 				#offset - 2*80 bytes
	addl %ebx, %eax 				#final offset in EAX
	movb $32, %cl 					#symbol's ASCII in cl 
	call mp1_poke 					#draw on screen


	movl 4(%esp), %ebx				#EBX contains arg
	addw %bx,crosshairs_x			#store x coord of crosshairs
									#in lower 16 bits
	shrl $16, %ebx	 				#shift right to get higher 16 bits 
	addw %bx, crosshairs_y 			#store y coord of crosshairs
	

	cmpw $LOWER_X_SCREEN_COORD, crosshairs_x 	#check if x < 0
	jl X_LO 									#jump out to Label
	cmpw $UPPER_X_SCREEN_COORD, crosshairs_x 	#check if x > 79
	jg X_HI 									#jump out to Label
	cmpw $LOWER_Y_SCREEN_COORD, crosshairs_y 	#check if y < 0
	jl Y_LO 									#jump out to Label
	cmpw $UPPER_Y_SCREEN_COORD, crosshairs_y 	#check if y > 24
	jg Y_HI 									#jump out to Label
	jmp draw_crosshairs 						#coord inside the screen


	X_LO: 							
	movl $LOWER_X_SCREEN_COORD, crosshairs_x 	#keep x coord at 0
	jmp draw_crosshairs 						#print out crosshairs
	X_HI:
	movw $UPPER_X_SCREEN_COORD, crosshairs_x 	#keep x coord at 79
	jmp draw_crosshairs 						#print out crosshairs
	Y_LO:
	movw $LOWER_Y_SCREEN_COORD, crosshairs_y 	#keep y coord at 0
	jmp draw_crosshairs 						#print out crosshairs
	Y_HI:
	movw $UPPER_Y_SCREEN_COORD,crosshairs_y 	#keep y coord at 24
	jmp draw_crosshairs 						#print out crosshairs


    draw_crosshairs:
    		#draw the new crosshairs
	xorl %eax, %eax 				#clear for use
	xorl %ebx, %ebx 	 			#clear for use
	movl crosshairs_x, %eax 		#temp store x
	movl crosshairs_y, %ebx 		#temp store y
	imull $2, %eax 				 	#offset - 2 bytes
	imull $160, %ebx 				#offset - 2*80 bytes
	addl %ebx, %eax 				#final offset in EAX

	movb $43, %cl 					#symbol's ASCII in cl

	call mp1_poke 					#draw on screen
	ret
################################################################################################/////////////////////////////////////////////////////////////////////////////////////////////////////



mp1_ioctl_getstatus:
		
		movl 4(%esp), %esi 			#
		
		pushl $4 					#
		call mp1_malloc 			#
		addl $4, %esp 				#
		movl %eax, %ebx 			#
		xorl %eax, %eax 			#
		
		movl $base_alive, %ecx 		#
		movb (%ecx), %al 			#
		shlb $1, %al 				#
		addl $1, %ecx 				#
		addb (%ecx), %al 			#
		shlb $1, %al 				#
		addl $1, %ecx 				#
		addb (%ecx), %al 			#
		shll $16, %eax
		
		xorl %edx, %edx 			#
		movl mp1_score, %edx 		#
		addl %eax, %edx 			#
		movl %edx, (%ebx) 			#
		
		movl %ebx, %edi 			#
			
		pushl $4 					#
		pushl %ebx 					#
		pushl %esi 					#
		call mp1_copy_to_user	 	#
		addl $12, %esp 				#
		
		movl %eax, %esi 			#
		
		cmpl $0, %esi 				#
		jne RETURN_KERNEL_FAULT 	#
		movl $0, %eax 				#
		pushl %edi 					#
		call mp1_free 				#
		addl $4, %esp 				#
		
		ret
	
		RETURN_KERNEL_FAULT:
		pushl %ebx 					#
		call mp1_free 				#
		popl %ebx 					#
		movl $-1, %eax 				#
		ret

	/*movl 4(%esp), %ebx			#arg in EBX	
	
	xorl %eax, %eax
	
	movl $base_alive, %eax 			#
	shll $16, %eax 					#eax now has 16,17,18
	addl $mp1_score, %eax 			#eax now has all correct val 
*/
	
	#%eax will have the return val
	#
/*		movl 4(%esp),%eax     
		pushl %ecx 		
		pushl %edi
		pushl %esi
		pushl %ebx
		movl %eax,%ebx                #SAVE ARGUMENT HERE
 		
 		XOR %ecx, %ecx 					#clear ecx
 										# Check Base 1
 		movl base_alive,%edi 			# Check the score of base 1
 		ANDl $0x000000FF, %edi 			#
 		cmpl $0,%edi 					# See if base 1 exists or not
 		je BASE2
 		ADDl $1, %ecx 					# base 1 is good 
 BASE2:
  		shll $1, %ecx 					# move one bit to the left for room 		
 		movl base_alive,%edi 			# Check the score of base 1
 		ANDl $0x0000FF00, %edi 			#
 		cmpl $0,%edi 					# See if base 1 exists or not
 		je BASE3
 		ADDl $1, %ecx 					# base 2 is good
 BASE3: 
  		shll $1, %ecx 					# move one bit  to the left for room 
 		movl base_alive,%edi 			# Check the score of base 1
 		ANDl $0x00FF0000, %edi 			#
 		cmpl $0,%edi 					# See if base 1 exists or not
 		je SCORETIME
 		ADDl $1, %ecx 					# base 2 is good
 SCORETIME:
  		shll $1, %ecx 					# move one bit to the left for room 	
 		shll $16, %ecx 					#shift left 16 bits
 		addl mp1_score,%ecx 			# put the score in
 		pushl %ecx 						# put mp1_score into stack
 										# memory stuff. 
 		movl %esp,%esi 					# save score bitstring location
 		#call mp1_copy_to_user
 		pushl $4
 		pushl %esi 
 		pushl %ebx
  		call mp1_copy_to_user
  		popl %ebx
		popl %ebx
		popl %ebx
  		cmpl $0, %eax 					# see if the return value was 0. if so has no error
  		je DONEGETSTATUS
  		movl $-1,%ecx 
 DONEGETSTATUS: 
		popl %ecx 						#
		popl %edi 						#
		popl %esi  						#
		popl %esi  						#
		popl %esi  						#
	
	#add %ax, %bx
*/
#
#	push $18
#	pushl (%ebx)
#	pushl 
#		ret


mp1_ioctl_endgame:
		movl mp1_missile_list, %ecx			#
		LOOPENDGAME: 
		cmp $0,%ecx 						# Check if ecx is null
		je DONEENDGAME
		movl NEXT(%ecx),%ecx 				# iterate ecx 
		pushl mp1_missile_list 				#
		call mp1_free 	 					#
		popl mp1_missile_list	 			#
		movl %ecx, mp1_missile_list 		#
		JMP LOOPENDGAME 					#
		DONEENDGAME:
		ret

		#delete_missile:
		/*
				then the missile should be erased from the screen,
				removed from the linked list, and its struct missile freed with mp1 free (see “Allocating and Freeing
				Memory”). Removing a missile from the list should be implemented as a separate function since you may need to
				perform this operation in more than one place in the code (possibly outside of the tasklet). In this document, we will
				refer to this function as mp1 missile remove, though you may name it whatever you chose.
		*/

		#pushl %ebp 						 #
		#movl %esp, %ebp 					 #

	
		#callee save
		#push %edx
	
				#-------My Personal Helper Labels--------#
		missile_remove:
			#TODO: Need to remove the missile from the screen
		
			#movl 4(%esp),%edx 				#move input node pointer arg to edx
			push %eax 						#
			push %ebx 						#
			push %ecx 						#
			push %esi 						#
			push %edi 						#
			
			cmpl $0, %edx 					#
			jle exit_update  				#
		  
		  	#Undrawing Missile
			movl X(%edx), %eax 				#
			movl Y(%edx), %ebx 				#
			shrl $16, %eax 					#
			shrl $16, %ebx 					#
			imull $2, %eax 					#	
			imull $160, %ebx 				#
			addl %ebx, %eax 				#
			movb $32, %cl 					#
			push %edx 						#
			call mp1_poke 					#
			popl %edx 						#



			#movl -4(%ebp), %edi 			#
			
			pushl %edi 						#
			pushl %edx 						#
			call mp1_missile_remove	 		#
			popl %edx 						#
			popl %edi	 			 		#
			#movl %eax, %edx	 			#
			jmp end_of_loop 				#
		
		#ret

		#-----My Personal Helper Functions-----#
		mp1_missile_remove:
			#TODO: REMOVE THE MISSILE
			pushl %ebp 					#
			movl %esp, %ebp 			#
			
			pushl %edi 					#
			#pushl %edx 				#
		    pushl %ebx	 				#
			
			movl 12(%ebp), %ecx			#ecx<- previous missile
			movl 8(%ebp), %eax			#eax now stores the pointer to the missile
			movl (%eax), %ebx			#ebx<- next missile
		 	cmpl $0, %ecx 				#
			je TOP_OF_LIST 				#
			movl %ebx, (%ecx)			#prev->next = next_missile
		REMOVE:	
			pushl %eax 					#
			call mp1_free				#Call to free the missile
			addl $4, %esp 				#
			movl %ebx, %edx 			#
			
			popl %ebx   				#poping callee saved registers
			#popl %edx 					#
			popl %edi 					#
			popl %ebp	 				#
			leave
			ret		
		TOP_OF_LIST:
			movl %ebx, mp1_missile_list #
			jmp REMOVE 					#
			leave 						#
			ret 						#