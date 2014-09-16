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
	UPPER_X_LIMIT = 79
	UPPER_Y_LIMIT = 24
	LOWER_X_LIMIT = 0
	LOWER_Y_LIMIT = 0

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

		#movl mp1_missile_list,%edx

		pushl %ebp				#set up base pointer
		movl %esp, %ebp			#stack pointer to base pointer
		
		
		pushl %edi 				#callee saved registers 
		pushl %esi 				#callee saved registers
		pushl %ebx 				#callee saved registers

		pushl %eax				#saving registers
		pushl %ecx				#saving registers
		pushl %edx 				#saving registers
		pushl %edi				#saving registers
		pushl %esi				#saving registers
		call update_missiles
		popl %esi 				#get back value
		popl %edi 				#get back value
		popl %edx 				#get back value
		popl %ecx				#get back value
		popl %eax  				#get back value

		pushl %eax				#saving registers
		pushl %ecx				#saving registers
		pushl %edx 			 	#saving registers
		pushl %edi				#saving registers
		pushl %esi				#saving registers
		call update_bases
		popl %esi 				#get back value
		popl %edi 				#get back value
		popl %edx 				#get back value
		popl %ecx				#get back value
		popl %eax 				#get back value

		pushl %eax				#saving registers
		pushl %ecx				#saving registers
		pushl %edx 				#saving registers
		pushl %edi				#saving registers
		pushl %esi				#saving registers
#		call update_crosshairs 	#has been include below
		popl %esi 				#get back value
		popl %edi 				#get back value
		popl %edx 				#get back value
		popl %ecx				#get back value
		popl %eax  				#get back value


		popl %ebx 				#get back callee saved value
		popl %esi 				#get back callee saved value
		popl %edi 				#get back callee saved value
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

		jump_table: 			#declaring a jump table
		.long mp1_ioctl_startgame, mp1_ioctl_addmissile, mp1_ioctl_movexhairs, mp1_ioctl_getstatus, mp1_ioctl_endgame
mp1_ioctl:

		movl 8(%esp), %ebx			#save argument to ebx 		

		jmp *jump_table(,%ebx,4)	#setting up switch case 	

		cmpl $0, %ebx 				#if less than 0
		jl finish
		cmpl $4,%ebx 				#if greater then 4
		jg finish
		jmp *jump_table(,%ebx,4) 	#go to the case 	

		finish:
		movl $-1, %eax 				#ret -1 if invalid
		ret

# ----------------- Functions private to this file -------------------

update_missiles:
		pushl %ebp 					#base pointer
		movl %esp, %ebp 			#stack pointer

#WE HAVE TO CHECK FOR NULL INITIALLY 
		cmpl $0, mp1_missile_list 	#if null then leave
		je end_of_update			#go to end of update_missiles			
		
		movl mp1_missile_list, %edx	#save pointer address	
		pushl %edx 					

		update_missiles_loop_start:
		popl %edx
		cmpl $0, %edx
		je end_of_update

		cmpl $0, EXPLODED(%edx)		#check if exploded
		je UPDATE_COORDINATES		#not exploded goto label
	
		
				#####EXPLODES THEN DO THE FOLLOWING:	
				#STOP moving
				#check for neighborhood explosion
				#draw explosion character
				#decrememnt exploded fld and when reach 0 rmv from list
				#free struct missile   
	
		
		movl $0, VX(%edx)		#make x velocity 0 
		movl $0, VY(%edx)		#make y velocity 0
	
						#checking for neighborhood explosion
		pushl %edx 		#save pointer
		pushl %edx 		#give arg
		call missile_explode #
		addl $4,%esp 	#move stack pointer
		popl %edx 		#get back pointer
		cmpl $0, %eax 	
		je dont_notify 		#%eax = 0 no surround explosions
		pushl %edx 		#save pointer
		pushl %edx 		#give arg
		call mp1_notify_user #
		addl $4,%esp 		#move stack pointer
		popl %edx 			#get back pointer
	
	dont_notify:	
							#popl %edx		
		
		decl EXPLODED(%edx)		#decrement this field 
		cmpl $0, EXPLODED(%edx)	#check if 0 remove missile
		je missile_remove 		#use equal as -ve vals are allowed																			
	
		jmp end_of_loop

		
	UPDATE_COORDINATES:	###if not exploding then do tasks
		#1)missile out of screen then erase missile from screen and
		# remove frm lnkd list and struct missile freed wid mp1_free
		#2)reach destination or exploded
		#3)simple moving
		
	   #Task 1 
		movl X(%edx), %eax
		movl Y(%edx), %ebx
		sarl $16,%eax
		sarl $16,%ebx

		cmpl $79, X(%edx)		#if x > 79  
		jl missile_remove 		#invalid coord 
		cmpl $0, X(%edx)		#if x < 0
		jl missile_remove 		#invalid coord
		cmpl $24, Y(%edx)		#if y > 24
		jl missile_remove 		#invalid coord
		cmpl $0, Y(%edx)		#if y < 0
		jl missile_remove 		#invalid coord

		imull $2, %eax 		 	#X*2 for 2 bytes each
		imull $160, %ebx		#Y*2*80 for 2 bytes each
		addl %ebx, %eax 		#put final offset in eax
		movb C(%edx), %cl  		#put char in cl to print
		pushl %edx 				#save pointer
		pushl %edx 				#give arg
		call mp1_poke 			#print on screen
		addl $4,%esp 			#reposition stack pointer
		popl %edx 				#get back pointer
		
		#1. Erase the variable
		#2. Call rmv_missile
		#3. Call mp1_free


START_TASK2:
	   #Task 2 
		#CASE 2
		# If X == DEST_X and Y==DEST_Y
		#then call missile_exploded
		
		movl X(%edx), %ebx		#save x coord in temp register
		sarl $16, %ebx 			#shift by 16 bits	
		cmpl %ebx, DEST_X(%edx) #If reached destination
		jne exploding			#go to label
		
		movl Y(%edx), %ebx 		#save y coord in temp register
		sarl $16, %ebx 			#shift by 16 bits
		cmpl %ebx, DEST_Y(%edx)	#If reached destination
		jne exploding			#go to label
		
			#		pushl %eax
			#		pushl %ecx
		pushl %edx 				#save pointer
		pushl %edx 				#give arg
		call missile_explode 	#
		addl $4,%esp 			#reposition stack pointer
		popl %edx 				#get back pointer

		
		cmpl $0, %eax 			#
		je exploding 			#

		pushl %eax 				#caller saved registers
		pushl %ecx 				#caller saved registers
		pushl %edx 				#caller saved registers
		pushl %edx 				#caller saved registers
		call mp1_notify_user
		addl $4,%esp 			#caller saved registers
		popl %edx 				#caller saved registers
		popl %ecx 				#caller saved registers
		popl %eax 				#caller saved registers

exploding:
		movl EXPLODED(%edx),%ebx
		cmpl $0, EXPLODED(%edx)
		je START_TASK3
		#decrement EXPLODED
		subl $1,EXPLODED(%edx)
		#movl EXPLODED(%edx),%ebx
		#movl $0,EXPLODED(%edx)
		cmpl $0, EXPLODED(%edx)
		jne skip2
		#   If 0, call free_missile
		jmp missile_remove
skip2:	
		#draw the EXPLOSION character

		movl X(%edx), %eax 		#store coord in temp registers
		movl Y(%edx), %ebx 		#store coord in temp registers
		sarl $16,%eax 			#shift right by 16 bits
		sarl $16,%ebx 		 	#shift right by 16 bits
		imull $2, %eax 			#X*2 for 2 bits each
		imull $160, %ebx		#Y*2*80 for 2 bits each
		addl %ebx, %eax 		#store offset in eax
		movb $64, %cl 			#store explosion character in cl
		pushl %edx 				#save pointer
		#pushl %edx 			#
		call mp1_poke 			#draw on screen
		#addl $4,%esp 
		popl %edx 				#get back pointer
		jmp end_of_loop
		
	
	
START_TASK3:

	
     #Task 3
	##if sceen pos has changed then draw blank and redraw new missile
	##in new position or else just redraw missile as it might not be der
		
	#Erase the old missile from screen
		movl Y(%edx), %ebx
		movl X(%edx), %eax
		sarl $16, %eax
		sarl $16, %ebx
		imul $160, %ebx		
		imul $2, %eax		
		addl %ebx, %eax		
		movb $32, %cl
		#pushl %ebp
		#movl %esp, %ebp
		pushl %edx
		pushl %edx
		call mp1_poke
		addl $4,%esp
		popl %edx
		#popl %ebp
		
		# Calculate new screen position
		movl VY(%edx), %eax
		movl VX(%edx), %ebx
		addl %ebx, X(%edx)
		addl %eax, Y(%edx)
		
		# Redraw the missile
		movl Y(%edx), %ebx
		movl X(%edx), %eax
		sarl $16, %eax
		sarl $16, %ebx
		imul $160, %ebx		# EAX holds X*160
		imul $2, %eax		# EAX holds Y*2
		addl %ebx, %eax		# Offset in EAX
		movb C(%edx), %cl
		#pushl %ebp
		#movl %esp, %ebp
		pushl %edx
		pushl %edx
		call mp1_poke
		addl $4,%esp
		popl %edx

		end_of_loop:
		movl %edx,%edi
		cmpl $0, %edx
		je end_of_update

		movl NEXT(%edx),%esi
		cmpl $0,%esi
		je end_of_update
		movl %esi,%edx
		pushl %edx
		xorl %esi,%esi
		jmp update_missiles_loop_start

		end_of_update:
		leave
		ret



update_bases:
		#offset = (24*2*80)+(18*2)=3876
		
		pushl %ebp 				#base pointer
		movl %esp, %ebp 		#stack pointer
		
	 	pushl %edi 				#callee saved registers
	 	pushl %esi 				#callee saved registers
	 	pushl %ebx 				#callee saved registers

	 	xorl %eax, %eax 		#clear registers for counters
		xorl %edi, %edi 		#clear registers for counters
		xorl %esi, %esi 		#clear registers for counters
		xorl %edx, %edx 		#clear registers for counters
		addl $3876,%eax 		#eax will contain offset

		movl $base_alive, %ebx 	#start reading Array

	outer_loop: #OUTER LOOP
	shiftx:
		cmpb $0, (%ebx) 		#check for dead base
		je deadbase

		cmpb $1, (%ebx) 		#check for alive base
		je alivebase
		
	deadbase:
		movl $dead_base_pic, %edx
		jmp inner_loop

	alivebase:
		movl $base_pic, %edx
	
	inner_loop:  #INNER LOOP

		movb (%edx), %cl 		#move display value in cl

		pushl %edx 				#save pointer
		pushl %edx 				#pass in as arg
		call mp1_poke 			#draw on screen
		addl $4,%esp 			#get back pointer
		popl %edx				#get back pointer

		addl $2, %eax
		addl $1, %edi 			
		addl $1, %edx
		cmpl $5, %edi
		jl inner_loop
		addl $1, %ebx
		#movl $base_pic, %ebx
		addl $32, %eax
		addl $1, %esi
		xorl %edi,%edi
		cmpl $3, %esi
		jl outer_loop

		
		popl %ebx 				#get back callee saved registers
		popl %esi 				#get back callee saved registers
		popl %edi 				#get back callee saved registers
		leave
		ret

#delete_missile:
		/*
				then the missile should be erased from the screen,
				removed from the linked list, and its struct missile freed with mp1 free (see “Allocating and Freeing
				Memory”). Removing a missile from the list should be implemented as a separate function since you may need to
				perform this operation in more than one place in the code (possibly outside of the tasklet). In this document, we will
				refer to this function as mp1 missile remove, though you may name it whatever you chose.
		*/

		
		missile_remove:
			
			cmpl $0, %edx
#			jle end_of_update					###should be equal to 0
			je end_of_update					#keep equal to cos -ve address work																		


			#clearing the previous missile position
			movl X(%edx), %ebx
			movl Y(%edx), %eax
			shrl $16, %ebx
			shrl $16, %eax
			imull $2, %ebx
			imull $160, %eax
			addl %ebx, %eax
			movb $32, %cl 		#32 is ascii for blank
			pushl %edx
			pushl %edx
			call mp1_poke
			addl $4,%esp
			popl %edx



			#movl -4(%ebp), %edi
			
			pushl %edi
			#pushl %edx
			pushl %edx
			movl NEXT(%edx),%ebx
			call mp1_missile_remove	
			addl $4,%esp
			popl %edi	
			jmp end_of_loop
		
		

		
mp1_missile_remove:
			
			pushl %ebp				#base pointer			
			movl %esp, %ebp 		#stack pointer	

			pushl %edi 				#callee saved registers
			pushl %esi 				#callee saved registers
		    pushl %ebx  			#callee saved registers

		    cmpl mp1_missile_list,%edx
		    je head_case

		    movl NEXT(%edx),%esi
		    movl %esi,NEXT(%edi)
		    movl $0,NEXT(%edx)

		    push %edx
		    pushl %edx
		    call mp1_free
		    addl $4, %esp
		    popl %edx
		    movl %esi,%edx
		    jmp end_delete

		    head_case:
		    movl NEXT(%edx),%esi
		    movl $0,NEXT(%edx)
		    pushl %edx
		    call mp1_free
		    addl $4, %esp
		    movl %esi,%edx
		    movl %edx,mp1_missile_list

		    end_delete:
		    popl %ebx
		    popl %esi
		    popl %edi

			leave
			ret

mp1_ioctl_startgame:
		#initialize all the variables 
		#offset = (160*12)+(2*40) = 2000
		#	xorl %ecx, %ecx
		#	addl $2000, %ebx
		pushl %ebp				#base pointer
		movl %esp, %ebp			#stack pointer to base pointer

		pushl %ebx
		pushl %esi
		pushl %edi
		movl $0x0, mp1_missile_list
		movl $0x0, mp1_score

		movl $base_alive, %eax
		movb $1, (%eax)
		movb $1, 1(%eax)
		movb $1, 2(%eax)
		movl $40, crosshairs_x
		movl $12, crosshairs_y
		
		popl %ebx 				#get back callee saved value 
		popl %esi 				#get back callee saved value
		popl %edi 				#get back callee saved value
		leave
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
		
		pushl %ebp					#base pointer
		movl %esp, %ebp				#stack pointer to base pointer

		movl 8(%esp), %edi			#esi gets *from arg

		pushl %ebx 					#save ebx
		pushl %edi 					#save edi
		pushl %esi 					#save esi

		#movl $33,%ebx
		pushl %edx 					#save edx
		#push %ebx 					#push size of dynamic memory
		pushl $33
		call mp1_malloc				#assign memory 
		addl $4,%esp 				#clear 33
		popl %edx 					#retrieve original stack pointer

		pushl $33 					#push size of dynamic memory
		pushl %edi 					#push *from arg
		pushl %eax					#push *to arg
		#unsigned long mp1_copy_from_user(*to,*from,n)
		call mp1_copy_from_user							#copy user missile struct 
		#eax contains whether valid transfer
		popl %esi 					#retrieve *to arg and store in edi
		popl %edi					#retrieve *from arg
		popl %ebx 					#temporarily store 33
		xorl %ebx,%ebx 				#clear 33
		xorl %edi,%edi			#clear esi (previously stored *from)

		cmpl $0,%eax				#check if copy was not valid
		jne no_copy
		
		#valid
		movl mp1_missile_list,%ebx
		movl %ebx,NEXT(%esi)
		movl %esi,mp1_missile_list
		#movl %esi,%edx

		jmp done_adding 					#jump to end

		no_copy:
		#xorl %edi,%edi
		pushl %esi 					#pass address of new dynamic space
		call mp1_free				#free the current cell 
		addl $4,%esp
		addl $-1,%eax 				#put -1 in eax to return
		jmp done_adding				#jump to end

		done_adding:
		#PRECAUTION: complete callee saves
		popl %esi
		popl %edi
		popl %ebx

		leave
		ret
		

mp1_ioctl_movexhairs:
	##draw a blank in place of x and y
	##position the crosshairs	
	
	#mp1_ioctl_movexhairs:
	##draw a blank in place of x and y
	##position the crosshairs	
	pushl %ebp
	movl %esp, %ebp
	
	xorl %eax, %eax
	xorl %ebx, %ebx

	movl crosshairs_x, %eax
	movl crosshairs_y, %ebx
	imul $2, %eax
	imul $160, %ebx
	addl %ebx, %eax
	movb $32, %cl
	call mp1_poke
	movl 8(%esp), %ebx			#EBX contains arg
	
	addw %bx,crosshairs_x		#shift x coord of crosshairs
	sarl $16, %ebx
	
	addw %bx, crosshairs_y
	cmpw $LOWER_X_LIMIT,crosshairs_x
	jl X_SET_LOWER_LIMIT
	
	cmpw $UPPER_X_LIMIT,crosshairs_x
	jg X_SET_HIGHER_LIMIT
	
	cmpw $LOWER_Y_LIMIT,crosshairs_y
	jl Y_SET_LOWER_LIMIT
	
	cmpw $UPPER_Y_LIMIT,crosshairs_y
	jg Y_SET_HIGHER_LIMIT
	
	jmp draw_crosshairs
	
	X_SET_LOWER_LIMIT:
	movl $0,crosshairs_x
	jmp draw_crosshairs
	
	X_SET_HIGHER_LIMIT:
	movw $79,crosshairs_x
	jmp draw_crosshairs
	
	Y_SET_LOWER_LIMIT:
	movw $0,crosshairs_y
	jmp draw_crosshairs
	
	Y_SET_HIGHER_LIMIT:
	movw $24,crosshairs_y
	jmp draw_crosshairs
    

    draw_crosshairs:
	#draw the new crosshairs
	xorl %eax, %eax
	xorl %ebx, %ebx
	movl crosshairs_x, %eax
	movl crosshairs_y, %ebx
	imul $2, %eax
	imul $160, %ebx
	addl %ebx, %eax
	movb $43, %cl
	call mp1_poke
	

	leave
	ret
	
mp1_ioctl_getstatus:
		pushl %ebp				#base pointer
		movl %esp, %ebp			#stack pointer to base pointer
		
		pushl %ebx
		pushl %esi
		pushl %edi

		pushl $4
		call mp1_malloc
		addl $4, %esp
		
		movl %eax, %ebx 	# ebx is now the pointer to the malloced memory
		xorl %eax, %eax
		xorl %ecx, %ecx

		movl $base_alive, %edx
		movb (%edx), %cl
		
		
		shlb $1, %cl
		addl $1, %edx
		addb (%edx), %cl
		shlb $1, %cl
		addl $1, %edx
		addb (%edx), %cl
		shll $17, %ecx
		
		

		xorl %eax, %eax
		movl mp1_score, %eax
		addl %ecx, %eax
		movl %eax, (%ebx)
		
		movl %ebx, %edi
			
		pushl $4
		pushl %ebx
		pushl 8(%ebp)
		call mp1_copy_to_user	
		addl $12, %esp
		
		movl %eax, %esi
		
		cmpl $0, %esi
		jne updating_getstatus
		movl $0, %eax
		pushl %edi
		call mp1_free
		addl $4, %esp
		

		popl %edi
		popl %esi
		popl %ebx
		#popl %ebp
		leave
		ret
	
		updating_getstatus:
		pushl %ebx
		call mp1_free
		popl %ebx
		movl $-1, %eax
		
		#popl %esp
		popl %edi
		popl %esi
		popl %ebx
		#popl %ebp
		leave
		ret

mp1_ioctl_endgame:
		pushl %ebp				#base pointer
		movl %esp, %ebp			#stack pointer to base pointer
	
		pushl %ebx
		pushl %esi
		pushl %edi

		movl mp1_missile_list, %edx						
	
	start_endgame_loop: 
		cmp $0,%edx 									
		je end_endgame_loop
	
		movl NEXT(%edx),%ebx 							 
		pushl mp1_missile_list
		call mp1_free 	
		popl mp1_missile_list	
		movl %edx, %ebx
		JMP start_endgame_loop
	
	end_endgame_loop:
		popl %edi
		popl %esi
		popl %ebx
		leave
		ret