
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
/*
		pushl %ebp
		movl %esp, %ebp
		pushl %ebx
		pushl %esi
		pushl %edi

		movl mp1_missile_list,%edx
		pushl %eax
		pushl %ecx
		pushl %edx
		pushl %edi
		pushl %esi
		#call update_missiles
		addl $8, %esp
		popl %edx
		popl %ecx
		popl %eax

		popl %edi
		popl %esi
		popl %ebx
*/
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
	#	addl $4, %esp			#save argument
		popl %esi
		popl %edi
		popl %edx
		popl %ecx				#save return value
		popl %eax
		
/*
		#call to delete missiles (test only)
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
		call delete_missile
	#	addl $4, %esp			#save argument
		popl %esi
		popl %edi
		popl %edx
		popl %ecx				#save return value
		popl %eax
		#movl mp1_missile_list,%edx		
*/

/*
		#redraw_crosshairs
		pushl %ebp
		movl %esp, %ebp
		pushl %ebx
		pushl %esi
		pushl %edi

		movl mp1_missile_list,%edx
		pushl %eax
		pushl %ecx
		pushl %edx
		pushl %edi
		pushl %esi
		#call update_missiles
		addl $8, %esp
		popl %edx
		popl %ecx
		popl %eax

		popl %edi
		popl %esi
		popl %ebx
		
*/
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


		movl 4(%esp), %ebx		#save 'cmd' in EBX

		#jmp *jump_table(,%ebx,4)		
		#movl $2, %ebx
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
/*
		movl mp1_missile_list,%edx        #point edx to stack head
        xorl %eax,%eax					  #clear eax
		xorl %ebx,%ebx                    #clear ebx
		xorl %ecx,%ecx                    #clear ecx
		#movl EXPLODED(%edx),%ebx	   	  #copy value to ebx		<-
		#cmpl %ebx,%ecx			  		  #compare value to 0
		cmpl EXPLODED(%edx),%ecx			  		  #compare value to 0
		je no_explosion		              #agar missile explodes
	
		#missile explodes
		

	no_explosion:
		#missile does not explode                                
		xor %ebx,%ebx			  #clear ebx
		movl X(%edx),%ebx		  #get low bits of x		<-
		movl VX(%edx),%ecx		  #get VX					<-
		add %bx,VX(%edx)		  #add VX to low X
		movl VX(%edx),%eax		  #copy new X to eax		<-
		movl %eax,X(%edx)		  #move new X to X			<-
		movl %ecx,VX(%edx)		  #store VX back to orig	<-
		movl %ecx,X(%edx)		  #update object X			<-
		xorl %eax,%eax			  #clear eax
		xorl %ebx,%ebx			  #clear ebx
		xorl %ecx, %ecx 		  #clear ecx
		movl Y(%edx),%ebx     	  #get low bits of y		<-
		movl VY(%edx),%ecx		  #get VY					<-
		add %bx,VY(%edx)	  	  #add VY to low Y			<-
		movl VY(%edx),%eax		  #copy new Y to eax		<-
		movl %eax,Y(%edx)		  #move new Y to Y			<-
		movl %ecx,VY(%edx)		  #store VY back to orig	<-
		movl %ecx,Y(%edx)		  #update object Y			<-
		xorl %eax,%eax			  #clear eax
		xorl %ebx,%ebx			  #clear ebx
		xorl %ecx, %ecx 		  #clear ecx
			
		#task1
		cmpl $0,X(%edx)
		jb CALL_DLT_MSL
		cmpl $79,X(%edx)
		jg CALL_DLT_MSL
		cmpl $0,Y(%edx)
		jb CALL_DLT_MSL
		cmpl $24,Y(%edx)
		jg CALL_DLT_MSL
		jmp skip_delete

	CALL_DLT_MSL:
		pushl %ebp
		movl %esp, %ebp
		pushl %ebx
		pushl %esi
		pushl %edi

		pushl %eax
		pushl %ecx
		pushl %edx
		pushl %edi
		pushl %esi
		#call delete_missile
		addl $8, %esp
		popl %edx
		popl %ecx
		popl %eax

		popl %edi
		popl %esi
		popl %ebx
			
		skip_delete:
		#task2
		#call function with arg
		pushl %ebp
		movl %esp, %ebp
		pushl %ebx
		pushl %esi
		pushl %edi

		pushl %eax
		pushl %ecx
		pushl %edx
		pushl %edi
		pushl %esi
		#call missile_explode
		addl $8, %esp
		popl %edx
		popl %ecx
		popl %eax

		popl %edi
		popl %esi
		popl %ebx


		decl EXPLODED(%edx)		  #decrement EXPLODED
		cmpl $0,EXPLODED(%edx)	  #check if 0
		jbe CALL_DLT_MSL_2		  #remove cell in list
		
		#re-draw missile here
		jmp skip_del

	CALL_DLT_MSL_2:
		pushl %ebp
		movl %esp, %ebp
		pushl %ebx
		pushl %esi
		pushl %edi

		pushl %eax
		pushl %ecx
		pushl %edx
		pushl %edi
		pushl %esi
		call delete_missile
		addl $8, %esp
		popl %edx
		popl %ecx
		popl %eax

		popl %edi
		popl %esi
		popl %ebx
		
		skip_del:

		#task3

*/
		ret
		#comment


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

/*		pushl %ebp
		movl %esp, %ebp

		xorl %eax,%eax			  #clear eax
		xorl %ebx,%ebx			  #clear ebx
		xorl %ecx, %ecx 		  #clear ecx
		xorl %edx,%edx			  #clear edx
		xorl %edi,%edi			  #clear edi
		xorl %esi, %esi 		  #clear esi
		addl $3876,%eax
		movl $base_pic, %ebx
		
	next_base:
	shiftx:
		movb (%ebx),%cl
		movl %edx,%eax

		push %edx
		call mp1_poke
		popl %edx
		addl $1,%edi
		addl $2,%edx
		addl $1,%ebx
		cmpl $5, %edi
		jl shiftx
		movl $base_pic,%ebx
		addl $1,%esi
		addl $32,%edx
		xorl %edi,%edi
		cmpl $3,%esi
		jl next_base
		ret		
*/

delete_missile:
		/*
				then the missile should be erased from the screen,
				removed from the linked list, and its struct missile freed with mp1 free (see “Allocating and Freeing
				Memory”). Removing a missile from the list should be implemented as a separate function since you may need to
				perform this operation in more than one place in the code (possibly outside of the tasklet). In this document, we will
				refer to this function as mp1 missile remove, though you may name it whatever you chose.
		*/
/*	
		#edx currently points to the present cell of the linked list
		xorl %eax,%eax 				#clear eax
		xorl %ebx,%ebx 				#clear ebx
		xorl %ecx,%ecx 				#clear ecx		
		movl mp1_missile_list,%eax	#get head of linked list

	#agar current cell hasn't been located
	check_again:
		#check if current node is located
		pushl %ebx					#save ebx to stack
		cmpl %eax,%edx 		 		#check if current node is located
		#movl %eax, %ebx			#save address of eax to ebx
		#cmpl %ebx, %edx			#check if current node is located
		je erase_cell				#agar located
		
		#agar current cell hasn't been found
		popl %ebx					#retrieve ebx from stack
		movl %eax,%ebx				#ebx gets the prev node
		#movl NEXT(%eax),%eax		#increment address pointer				<-
		addl $1,%eax
		jmp check_again				#loop back

	#agar current cell HAS been located
	erase_cell:
		popl %ebx 					#retrieve ebx from sta:q

		movl %edx,%ecx
		popl %edx
		
		movl %ecx,NEXT(%ebx)		#prev->next = curr->next				<-
		movl %ecx,%edx 				#update curr pointer
		
		push %eax
		push %ebx
		push %ecx
		push %edx
		call mp1_free(%eax)			#free the current cell 
		pop %edx
		pop %ecx
		pop %ebx
		pop %eax		

*/
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
	/*
			int mp1 ioctl addmissile (struct missile* user missile);
			This ioctl must add a new missile to the game. The parameter is a pointer to a struct missile in user space. This
			function needs to copy the user’s missile into a dynamically allocated buffer in kernel space. If either the dynamic
			memory allocation (see “Allocating and Freeing Memory” below) or the data copy (see “Moving data to/from the
			kernel”) fails, this function should return -1. If it does fail, it should be sure to free any memory it has allocated before
			returning. If it succeeds, it should add the new missile into the linked list and return 0.
		*/
		#get the *from pointer
/*	
		#popl %esi
		movl 4(%esp), %esi			#EBX contains arg
		#movl $32,%ebx

		#push %eax
		#push %ebx
		#push %ecx
		push %edx
		call mp1_malloc				#free the current cell 
		movl 4(%esp), %edi			#EBX contains arg
		#popl %edi					#pointer to space just freed
		pop %edx
		#pop %ecx
		#pop %ebx
		#pop %eax

		#now, edi is the 36bit space i created

		#push %eax
		#push %ebx
		#push %ecx
		#push %edx
		push $33
		push %edi
		push %esi
		#unsigned long mp1_copy_from_user(*to,*from,n)
		call mp1_copy_from_user							#copy user missile struct 
		movl 4(%esp), %eax								#contains whether valid transfer
		popl %esi
		popl %edi
		#popl %edx
		#pop %edx
		#pop %ecx
		#pop %ebx

		xorl %esi,%esi 				#clear esi
		cmpl $0,%eax				#check if copy was not valid
		jg invalid

	#valid
		xorl %eax,%eax
		movl mp1_missile_list,%esi	#get head of linked list
		push %ebx
		#push %ecx
		#push %edx
		xorl %ebx,%ebx

		re_check:
		#check if current node is located
		#pushl %ebx					#save ebx to stack
		#movl %esi, %ebx				#save address of eax to ebx
		cmpl %esi,%edx 		 		#check if current node is located
		#cmpl %ebx, %edx			#check if current node is located
		je add_cell					#agar located
		
		#agar current cell hasn't been found
		#popl %ebx					#retrieve ebx from stack
		movl %esi,%ebx				#ebx gets the prev node
		#movl NEXT(%eax),%eax		#increment address pointer				<-
		addl $33,%esi
		jmp re_check				#loop back

		add_cell:
		push %edx
		movl NEXT(%edx),%esi		#ecx stores the next node				<-
		#addl $32,%edx
		
		movl %edi,NEXT(%edx)
		movl %esi,NEXT(%edi)

		#movl %edx,%ecx
		xorl %edx,%edx
		popl %edx
		
		#movl %ecx,NEXT(%ebx)		#prev->next = curr->next				<-
		#movl %ecx,%edx 				#update curr pointer

		#popl %ebx
		#popl %ecx
		#popl %edx
		jmp fin

	invalid:
		xorl %eax,%eax
		#push %eax
		#push %ebx
		#push %ecx
		#push %edx
		push %edi
		call mp1_free				#free the current cell 
		pop %edi
		#pop %edx
		#pop %ecx
		#pop %ebx
		#pop %eax
		addl $-1,%eax
		jmp fin

		fin:

		ret
*/
#/*
		push %esi
		push %edi
		push %edx
		push %eax

		movl 4(%esp), %esi			#EBX contains arg
		push %edx
		call mp1_malloc				#free the current cell 
		movl 4(%esp), %edi			#EBX contains arg
		#popl %edi					#pointer to space just freed
		pop %edx
		#now, edi is the 36bit space i created

		push $33
		push %edi
		push %esi
		#unsigned long mp1_copy_from_user(*to,*from,n)
		call mp1_copy_from_user							#copy user missile struct 
		movl 4(%esp), %eax								#contains whether valid transfer
		popl %esi
		popl %edi

		xorl %esi,%esi 				#clear esi
		cmpl $0,%eax				#check if copy was not valid
		jg invalid

	#valid
		xorl %eax,%eax
		movl mp1_missile_list,%esi	#get head of linked list
		push %ebx
		xorl %ebx,%ebx

		re_check:
		#check if current node is located
		cmpl %esi,%edx 		 		#check if current node is located
		je add_cell					#agar located
		
		#agar current cell hasn't been found
		movl %esi,%ebx				#ebx gets the prev node
		addl $33,%esi
		jmp re_check				#loop back

		add_cell:
		push %edx
		movl NEXT(%edx),%esi		#ecx stores the next node				<-
		
		movl %edi,NEXT(%edx)
		movl %esi,NEXT(%edi)

		xorl %edx,%edx
		popl %edx

		jmp fin

	invalid:
		xorl %eax,%eax
		push %edi
		call mp1_free				#free the current cell 
		pop %edi
		addl $-1,%eax
		jmp fin

		fin:
		popl %eax
		popl %edx
		popl %edi
		popl %esi
#*/
		ret


mp1_ioctl_movexhairs:
	##draw a blank in place of x and y
	##position the crosshairs	

	 movl 4(%esp), %ebx			#EBX contains arg
	# movl $40,crosshairs_x
	# movl $12,crosshairs_y
	add %bx,crosshairs_x		#shift x coord of crosshairs

	shrl $16, %ebx	
	add %bx, crosshairs_y
	
	#draw the new crosshairs
	movl $crosshairs_x, %eax
	movl $crosshairs_y, %ebx
	imull $2, %eax
	imull $160, %ebx
	
	addl %ebx, %eax
	mov $43, %cl
	pushl %edx
	call mp1_poke
	popl %edx

	ret

			#	cmpl $24,crosshairs_y
			#	jg Y_HI
			#	cmpw $0,crosshairs_y
			#	jl Y_LO

			#	cmpw $0,crosshairs_x
			#	jl X_LO


			#	cmpw $79,crosshairs_x
			#	jg X_HI

			#	X_HI:
			#	movw $79,crosshairs_x
			#	jmp draw_crosshairs

			#	X_LO:
			#	movw $0,crosshairs_x
			#	jmp draw_crosshairs

			#	Y_HI:
			#	movw $24,crosshairs_y
			#	jmp draw_crosshairs

			#	Y_LO:
			#	movw $0,crosshairs_y
	


mp1_ioctl_getstatus:
		ret

mp1_ioctl_endgame:
		ret
