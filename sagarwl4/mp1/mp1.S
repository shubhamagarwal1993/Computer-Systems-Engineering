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
	BASE_INITIAL = 0x00888888


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
		call update_missiles
		call redraw_bases 
		call redraw_crosshairs
		ret

# int mp1_ioctl(unsigned long arg, unsigned int cmd)
# The dispatch function for the MP1 ioctls - should use the cmd argument
# and a jumiptable to execute one of the specific ioctls implemented below.
# Inputs   : unsigned long arg - parameter to the mp1_ioctl_....
#          : unsigned int cmd  - specifies which mp1_ioctl_... function 
#          :                     to execute
# Outputs  : Returns an integer - depends on which ioctl() function is called
# Registers: Standard C calling convention

.globl mp1_ioctl

jump_table:
.long mp1_ioctl_startgame, mp1_ioctl_addmissile,mp1_ioctl_movexhairs,mp1_ioctl_getstatus,mp1_ioctl_endgame

mp1_ioctl:

	movl 8(%esp),%esi # Move cmd value into ESI 

	cmpl $0,%esi 	  # Check for correctness of values
	jl exit_table
	cmpl $4,%esi
	jg exit_table

	jmp *jump_table(,%esi,4)	# Doubt: How do Jump Tables Work and what is the *for
		ret

	exit_table:
		movl $-1,%eax	#Verfiry Correctness
		ret


# ----------------- Functions private to this file -------------------
# 
update_missiles:

		pushl %ebp 		# Push Old Base Pointer
		movl %esp,%ebp	# Update the Base Pointer
		pushl %ebx
		pushl %edi
		pushl %esi

		# Move Head of the Linked List into the Edi
		movl mp1_missile_list,%edi  

		xorl %esi,%esi
# EDI - Current Missle 
# ESI - Parent
# EBX - Shifted X
# EDX - Shifter Y
start_traversal:

		cmpl $0,%edi	   			# check for NULL Ptr
		je end_of_list

		cmpl $0,EXPLODED(%edi)		# Check if the missle is destroyed 
		je not_destroyed  

		# If it's Not Zero then it must be exploding		
		jmp currently_exploding
	
	not_destroyed:
		
		# Erase Old Missile
		# EBX - Shifted X
		# EDX - Shifter Y
		movl X(%edi),%ebx		 # Mov X Value in ebx
		shrl $16,%ebx			 # Shift Bits
		movl Y(%edi),%edx
		shrl $16,%edx

		# Erase Missile
		movl %edx,%eax
		imull $160,%eax  # Mulitply by 160
		addl %ebx,%eax	 # Add two
		addl %ebx,%eax
		movb $32,%cl
		pushl %esi  			# Push 4 regs
		pushl %edi
		pushl %ebx
		pushl %edx
		call mp1_poke	# Print Space
		popl %edx
		popl %ebx
		popl %edi 				# Pop 4 regs
		popl %esi

		# Update x and y
		movl VX(%edi),%eax		
		addl %eax, X(%edi)		# X = VX + X
		movl VY(%edi),%eax		
		addl %eax, Y(%edi)		# Y = VY + Y

		# EBX - Shifted X
		# EDX - Shifter Y
		# Check if out of range
		# X 
		movl X(%edi),%ebx		 # Mov X Value in ebx
		shrl $16,%ebx			 # Shift Bits
		movl Y(%edi),%edx
		shrl $16,%edx

		#Check X
		cmpl $79,%ebx			 # Right Compare
		jg missile_out_of_range  		
		cmpl $0,%ebx			 # Left Compare
		jl missile_out_of_range

		# Check Y
		cmpl $0,%edx
		jl missile_out_of_range
		cmpl $24,%edx
		jg missile_out_of_range

		jmp in_range

	missile_out_of_range:

		
		pushl %esi 					# Push Parent
		pushl NEXT(%edi)			# Push Child
		call mp1_missile_remove		# Remove Missile 
		popl %edi 					# Load as the next node to be traversed 
		popl %esi 					# Load Papa 
		jmp start_traversal 		# Proceed to Next
		
		# EBX - Shifted X
		# EDX - Shifter Y	
	in_range:
		#Check Destination
		# X Dest
		movl DEST_X(%edi), %eax
		cmpl %eax,%ebx
		jne not_reached			 # Not Equal, So Proceed without Explosion
		# Y Dest
		movl DEST_Y(%edi), %eax
		cmpl %eax,%edx
		jne not_reached 	 	 #Not Equal, So Proceed without Explosion
		
		jmp dont_remove_missile
		# Missile at its Destination, Commence Explosion
		# First_time_explosion - for missile counter 50, to check for surroundings
	
	currently_exploding:

		subl $1,EXPLODED(%edi)
		cmpl $0, EXPLODED(%edi)
		jg dont_remove_missile

		## Initiate Process to remove the Missile

		
		pushl %esi 		   # Push Parent
		pushl NEXT(%edi)  # Push Next Element in List
		call mp1_missile_remove
		popl %edi
		popl %esi
		
		# Missile Removed. Start Traversing Again
		jmp start_traversal

	dont_remove_missile:	
		#Save Registers
		pushl %edi 
		pushl %esi		
		#Push Arguments
		pushl %edi
		call missile_explode
		addl $4,%esp			#Pop Arguments
		#Restore registers
		popl %esi
		popl %edi
		# Notification Check
		cmpl $0,%eax 				# If no Missiles Exploded
		jne draw_missile_explosion	# Skips Notification
		pushl %esi  			    # Push 2 regs
		pushl %edi
		call mp1_notify_user	# Call Notify User
		popl %edi 					# Pop 2 regs
		popl %esi
	
	# Draws Exploded Missile
	draw_missile_explosion:		
		
		# Drawing Missile at place of explosion
		# Shiftting the Bits
		movl X(%edi),%ebx
		shrl $16,%ebx
		movl Y(%edi),%edx
		shrl $16,%edx
		# Calculating Video Card Length and calculating the Offset
		imull $2,%ebx
		imull $160,%edx
		movl %ebx,%eax
		addl %edx,%eax
		movb $64,%cl
		pushl %esi
		pushl %edi
		call mp1_poke
		popl %edi
		popl %esi

		jmp next_missile

	# Redraw Missile to update Position if not exploded
	# EBX - Shifted X
	# EDX - Shifter Y		
	not_reached:
		imull $2,%ebx
		imull $160,%edx
		movl %edx,%eax		# A <- D*160
		addl %ebx,%eax		# A <- A + B*2; eax contains the pixel address
		movb $194,%cl 		# Missile Character in CL 
		pushl %edi 			# Push Missile Pointer
		pushl %esi 			# Push Papa
		call mp1_poke
		popl %esi 			# Pop Papa
		popl %edi 			# Pop Missile

	next_missile:
		xorl %esi,%esi
		movl %edi,%esi 		 # ESI Contains the Parent
		movl NEXT(%edi),%edi # Update the address of the next Missile in %edi 
		jmp start_traversal
end_of_list:
		
		popl %esi
		popl %edi
		popl %ebx
		leave
		ret

redraw_bases:
	
		pushl %ebp 		# Push Old Base Pointer
		movl %esp,%ebp	# Update the Base Pointer
		pushl %ebx
		pushl %edi
		pushl %esi

	# First Base
		xorl %eax,%eax
		movl base_alive, %ecx
		movb %cl,%al
		cmpb $0,%al
		jne use_alive_1

		leal dead_base_pic,%esi
		#movb (%esi),%cl
		jmp start_draw_values_1

		use_alive_1:
			leal base_pic,%esi

	start_draw_values_1:
		movl $3874, %eax      # First Pixel minus 2 
		movl $0,%ebx		  #  Counter
		
		start_draw_1:

			movb  (%ebx,%esi),%cl  # Update String Value
			addl $2,%eax			 # Update the X coordinate
			call mp1_poke
			inc %ebx
			cmpl $5,%ebx
			jl start_draw_1

	# Second Base
		
		xorl %eax,%eax
		movl base_alive, %ecx
		shrl $8,%ecx
		movb %cl,%al
		cmpb $0,%al 
		jne use_alive_2

		leal dead_base_pic,%esi
		jmp start_draw_values_2

		use_alive_2:
			leal base_pic, %esi

		start_draw_values_2:
		movl $3914, %eax      # First Pixel minus 2 
		movl $0,%ebx		  # Inner Counter
			
		start_draw_2:

			movb (%ebx,%esi),%cl  # Update String Value
			addl $2,%eax			 # Update the X coordinate
			call mp1_poke
			inc %ebx
			cmpl $5,%ebx
			jl start_draw_2

	# Third Base

		
		xorl %eax,%eax
		movl base_alive, %ecx
		shrl $16,%ecx
		movb %cl,%al
		cmpb $0,%al
		jne use_alive_3

		
		leal dead_base_pic,%esi
		jmp start_draw_values_3

		use_alive_3:
			leal base_pic, %esi
		
		start_draw_values_3:
		movl $3954, %eax      # First Pixel minus 2 
		movl $0,%ebx		  # Inner Counter
			
		start_draw_3:			
			movb (%ebx,%esi),%cl  # Update String Value
			addl $2,%eax			 # Update the X coordinate
			call mp1_poke
			inc %ebx
			cmpl $5,%ebx
			jl start_draw_3			
	# Forth Base
		popl %esi
		popl %edi
		popl %ebx
		leave
		ret

redraw_crosshairs:

		pushl %ebp 		# Push Old Base Pointer
		movl %esp,%ebp	# Update the Base Pointer
		pushl %ebx
		pushl %edi
		pushl %esi

	
		movl crosshairs_x,%eax # eax contains x
		movl crosshairs_y,%esi # esi contains y
		movb $43,%cl 	# Character for crosshair 
		imull $160,%esi
		imull  $2,%eax
		addl  %esi,%eax
		call mp1_poke

		popl %esi
		popl %edi
		popl %ebx
		leave
		ret
	

mp1_ioctl_startgame:

		pushl %ebp 		# Push Old Base Pointer
		movl %esp,%ebp	# Update the Base Pointer
		pushl %ebx
		pushl %edi
		pushl %esi

		
		movl $0,mp1_missile_list
		movl $BASE_INITIAL,%eax
		movl %eax,base_alive
		movl $0,mp1_score
		movl $40,crosshairs_x
		movl $12, crosshairs_y 
		
		popl %esi
		popl %edi
		popl %ebx
		leave
		ret


mp1_ioctl_addmissile:

	pushl %ebp 		# Push Old Base Pointer
	movl %esp,%ebp	# Update the Base Pointer
	pushl %ebx
	pushl %edi
	pushl %esi


	# Initiate Add Missile Process
	# Allocate Memory in Kernel, Call mp1_malloc

	pushl $33 		# PUSH List Size Parameter
	call mp1_malloc
	addl $4,%esp 	# POP the Magic Number 
	cmpl $0,%eax 	# Check if NULL Ptr
	je mp1_ioctl_addmissile_failure

	movl %eax,%esi 	#Copy the Mem address in ESI
	# esi - contains memory value from malloc
	# ebx - contains memory from user space 

	movl 8(%ebp),%ebx # Missile Address from User Space

	pushl %esi 		#Save ESI
	pushl $33		#Push the Magic Number 
	pushl %ebx		#Missile From User
	pushl %eax		#Missile From Malloc
	call mp1_copy_from_user
	addl $12,%esp 	#Pop three arguments from the Stack
	popl %esi 		# Restore ESI
	cmpl $0,%eax	# Check for mp1_copy success
	jne mp1_ioctl_addmissile_failure

	movl mp1_missile_list,%eax 		   #Move Top of list to the NEXT of new Element
	movl %eax, NEXT(%esi)
	movl %esi, mp1_missile_list		   #Update the Hea Ptr
	 	

	# Result: Sucess
	movl $0, %eax
	movl %eax, -4(%ebp)
		
	popl %esi
	popl %edi
	popl %ebx
	leave
	ret


	#Failure
	mp1_ioctl_addmissile_failure:
		movl $-1,%eax

		popl %esi
		popl %edi
		popl %ebx
		leave
		ret



mp1_ioctl_movexhairs:
	
		pushl %ebp 		# Push Old Base Pointer
		movl %esp,%ebp	# Update the Base Pointer
		pushl %ebx
		pushl %edi
		pushl %esi


		# Clear Old Xhair Possition
		movl crosshairs_x, %eax
		movl crosshairs_y, %ebx
		imull $2,%eax
		imull $160, %ebx
		addl %ebx,%eax			# Video Array Coordinate 
		movb $32, %cl 			# Space Value
		call mp1_poke			# Cleaned xhair

		# ESI _32 Bit Update
		# ebx 
		# ecx 
		#Update the parameters
		movl 8(%ebp),%esi 		# Updated xhair Value
		movl %esi,%eax			# Copy to eax
		addw %ax,crosshairs_x	# Add low 16 to xhair_X  
		shrl $16,%eax			# Shift 16 bits 
		addw %ax,crosshairs_y	# Add Hight 16 to xhair_Y
		
		#Updated Values, Check for bounds
		# eax - X
		# ebx - Y	
		movl crosshairs_x,%eax
		movl crosshairs_y,%ebx

		#Check Left
		cmpl $0,%eax
		jl xhair_left_err
		#Check right
		cmpl $79,%eax
		jg xhair_right_err
		#Check Bottom
	xhair_top_chk:	
		cmpl $0,%ebx
		jl xhair_top_err
		#Check Top
		cmpl $24,%ebx
		jg xhair_bottom_err
	
	xhair_check_complete:

		#draw update value of xhair
		movl crosshairs_x,%eax
		movl crosshairs_y,%ebx
		imull $2,%eax
		imull $160, %ebx
		addl %ebx,%eax			# Video Array Coordinate 
		movb $43, %cl 			# Space Value
		call mp1_poke			# Updated xhair

		#Set Return value and return :)
		movl $0,%eax
		popl %esi
		popl %edi
		popl %ebx
		leave
		ret
		
	xhair_left_err:
		movl $0,crosshairs_x
		 
		jmp xhair_check_complete

	xhair_right_err:
		movl $79,crosshairs_x
		 
		jmp xhair_check_complete

	xhair_top_err:
		movl $0, crosshairs_y
		 
		jmp xhair_check_complete

	xhair_bottom_err:
		movl $24,crosshairs_y
		
		
		jmp xhair_check_complete



mp1_ioctl_getstatus:

		pushl %ebp 		# Push Old Base Pointer
		movl %esp,%ebp	# Update the Base Pointer
		pushl %ebx
		pushl %edi
		pushl %esi

		
		# eax - contains values of array of bytes
		# ebx - answer

		movl base_alive,%ebx 	# Copy Array into ebi

		# First Base 

		xorl %eax,%eax
		movb %bl,%al 			# Byte 0 
		shrl $8,%ebx 			# Shift ebx by 8 bits
		cmpb $0,%al 			# Check if the Byte Value is more than zero
		je city_one_destroyed
		addl $1,%ebx

	city_one_destroyed:

		xorl %eax,%eax
		movb %bl,%al
		shrl $8,%ebx
		cmpb $0,%al
		je city_two_destroyed
		addl $2,%ebx

	city_two_destroyed:	

		xorl %eax,%eax
		movb %bl,%al
		cmpb $0,%al
		je city_three_destroyed
		addl $4,%ebx

	city_three_destroyed:	 

		shll $16,%ebx 		# Shift right by 16 Bits to make room for the answer
		movw mp1_score,%bx # Copy over to MP1

		# ebx - answer to be sent 

		# Allocate memory from Malloc


		pushl %ebx 	# Save ebx Register
		pushl $4 	# Value for Malloc
		call mp1_malloc
		addl $4,%esp
		popl %ebx 	# Save EBX - Our Answer 
		movl %eax,%esi # Save Location of the memory from malloc

		movl %ebx,(%eax) # Move answer to the newly allocated memory

		movl 8(%ebp),%edx # EDx contains the argument from user

		## Calling copy to user

		pushl %esi 	# Save esi, register to be saved

		pushl $4 	# Length to be copied 
		pushl %eax  # The Pointer from Malloc 
		pushl %edx	# The Pointer to User
		call mp1_copy_to_user
		addl $12,%esp # Pop # arguments 

		popl %esi 	# pop saved register esi

		pushl %esi 	# Push Argument for MP1_free memory 
		call mp1_free
		addl $4,%esp
		
		popl %esi
		popl %edi
		popl %ebx
		leave
		ret


mp1_ioctl_endgame:
		
		pushl %ebp 		# Push Old Base Pointer
		movl %esp,%ebp	# Update the Base Pointer
		pushl %ebx
		pushl %edi
		pushl %esi

		
		movl mp1_missile_list,%esi # Load the top Pointer
	
	start_free_memory:
		cmpl $0,%esi	# Check for NULL 
		je exit_game
		movl NEXT(%esi),%edi #Get the next Pointer
		pushl %edi 	# Save Register
		
		# call mp1_free
		pushl %esi
		call mp1_free
		addl $4,%esp # Pop the arguments
		
		popl %edi # pop edi
		movl %edi,%esi	# move edi to esi 
		
		jmp start_free_memory
		
	
	exit_game:
		popl %esi
		popl %edi
		popl %ebx
		leave
		ret


		# This Function Does not Use C Calling Conventions
		# Frame Pointer remains same as the function that called 
		# Arguments are passed through registers
mp1_missile_remove:
		# EDI Still contains Missile Current Pointer
		# ESI Contains the Parent

		# Erase Old Missile
		# EBX - Shifted X
		# EDX - Shifter Y

		pushl %ebp 		# Push Old Base Pointer
		movl %esp,%ebp	# Update the Base Pointer
		pushl %ebx
		pushl %edi
		pushl %esi


		movl X(%edi),%ebx		 # Mov X Value in ebx
		shrl $16,%ebx			 # Shift Bits
		movl Y(%edi),%edx
		shrl $16,%edx

		# Erase Missile
		movl %edx,%eax
		imull $160,%eax  # Mulitply by 160
		addl %ebx,%eax	 # Add two
		addl %ebx,%eax
		movb $32,%cl
		pushl %esi  			# Push 4 regs
		pushl %edi
		pushl %ebx
		pushl %edx
		call mp1_poke	# Print Space
		popl %edx
		popl %ebx
		popl %edi 				# Pop 4 regs
		popl %esi

		# Remove from Linked List
		#CLI
		movl NEXT(%edi),%eax  # Get Next Missile in List

		cmpl mp1_missile_list,%edi 		# Parent is Null, Then this is the missile Head

		je set_as_head
		# If not make the Connection
		movl %eax,NEXT(%esi)
		jmp remove_this_rouge_missile
		# Set as Head, due to NULL Parent Case 
	set_as_head:
		movl %eax,mp1_missile_list
		#STI
		# Free Memory 
		# EDI - Memory Pointer in User Space
	remove_this_rouge_missile:
		pushl %edi
		call mp1_free
		popl %edi
	
		popl %esi
		popl %edi
		popl %ebx
		leave
		ret