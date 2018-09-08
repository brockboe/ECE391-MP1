
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
		PUSHL %EBP
		MOVL %ESP, %EBP
		PUSHL %EBX
		PUSHL %ESI
		PUSHL %EDI

		#Begin by going through the missile list and updating everything
		MOVL mp1_missile_list, %EAX
list_loop:
		PUSHL %EAX
		PUSHL %ESI
		PUSHL %EDI
		PUSHL %EAX
		CALL update_missiles
		ADDL $4, %ESP
		POPL %EDI
		POPL %ESI
		POPL %EAX
		MOVL NEXT(%EAX), %EAX
		CMP $0, %EAX
		JNE list_loop

		POPL %EDI
		POPL %ESI
		POPL %EBX
		LEAVE
		RET

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

#void update_missiles(struct * missile)
update_missiles:
		PUSHL %EBP
		MOVL %ESP, %EBP
		PUSHL %EBX
		PUSHL %ESI
		PUSHL %EDI

		MOVL 8(%EBP), %EAX
		#Check if missile is exploding
		MOVL EXPLODED(%EAX), %EBX
		CMPL $0, %EBX
		JG update_explode_missile

		#Check if missile is out of bounds
		MOVL Y(%EAX), %EBX
		SHRL $16, %EBX
		CMPL $0, %EBX
		JL update_OB_missile
		CMPL $24, %EBX
		JG update_OB_missile
		MOVL X(%EAX), %EBX
		SHRL $16, %EBX
		CMPL $0, %EBX
		JL update_OB_missile
		CMPL $79, %EBX
		JL update_OB_missile

		#Otherwise update missile
		PUSHL %EAX
		PUSHL %ECX
		PUSHL %EDX
		PUSHL %EAX
		CALL missile_moving
		ADDL $4, %ESP
		POPL %EDX
		POPL %ECX
		POPL %EAX

update_missiles_done:
		POPL %EDI
		POPL %ESI
		POPL %EBX
		LEAVE
		RET

update_explode_missile:
		PUSHL %EAX
		PUSHL %ECX
		PUSHL %EDX
		PUSHL %EAX
		CALL missile_exploding
		ADDL $4, %ESP
		POPL %EDX
		POPL %ECX
		POPL %EAX
		JMP update_missiles_done

update_OB_missile:
		PUSHL %EAX
		PUSHL %ECX
		PUSHL %EDX
		PUSHL %EAX
		CALL missile_offscreen
		ADDL $4, %ESP
		POPL %EDX
		POPL %ECX
		POPL %EAX
		JMP update_missiles_done


# long int calc_vid_offset(int x, int y)
calc_vid_offset:
		PUSHL %EBX
		MOVL %ESP, %EBX
		PUSHL %EBX
		PUSHL %ESI
		PUSHL %EDI

		XOR %EAX, %EAX
		MOVL 12(%EBP), %EAX		#grab y position
		IMULL $80, %EAX
		IMULL $2, %EAX
		MOVL %EAX, %EBX
		MOVL 8(%EBP), %EAX		#Grab x position
		IMULL $2, %EAX
		ADDL %EBX, %EAX
		POPL %EDI
		POPL %ESI
		POPL %EBX
		LEAVE
		RET

# void missile_offscreen(struct * missile)
# Local Variables	:	Old X (ebp-4), Old Y (ebp-8)
missile_offscreen:
		PUSHL %EBX
		MOVL %ESP, %EBX
		ADDL $-8, %ESP		#save space for local vars
		PUSHL %EBX
		PUSHL %ESI
		PUSHL %EDI

		MOVL 8(%EBP), %EAX	#Store the pointer in eax
		MOVL X(%EAX), %EBX
		MOVL VX(%EAX), %ECX
		SUBL %ECX, %EBX		#Calculate the old x position
		SHRL $16, %EBX
		MOVL %EBX, -4(%EBP)	#store the old x position

		MOVL Y(%EAX), %EBX
		MOVL VY(%EAX), %ECX
		SUBL %ECX, %EBX		#Calculate the old y position
		SHRL $16, %EBX
		MOVL %EBX, -8(%EBP)	#store the old x position

		PUSHL %EAX			#Delete missile from list
		PUSHL %ECX
		PUSHL %EDX
		PUSHL %EAX
		CALL delete_missile
		ADDL $4, %ESP
		POPL %EDX
		POPL %ECX
		POPL %EAX

		PUSHL %EAX 			#Calculate the video offset and print space char
		PUSHL %ECX
		PUSHL %EDX
		PUSHL -8(%EBP)
		PUSHL -4(%EBP)
		CALL calc_vid_offset
		MOVB $32, %CL
		CALL mp1_poke
		ADDL $8, %ESP
		POPL %EDX
		POPL %ECX
		POPL %EAX

		POPL %EDI
		POPL %ESI
		POPL %EBX
		LEAVE
		RET

# void missile_exploding(struct * missile)
missile_exploding:
		PUSHL %EBP
		MOVL %ESP, %EBP
		PUSHL %EBX
		PUSHL %ESI
		PUSHL %EDI

		MOVL 8(%EBP), %EBX	#Put the missile pointer into ebx

		#Call missile_explode
		PUSHL %EAX
		PUSHL %ECX
		PUSHL %EDX
		PUSHL %EBX
		CALL missile_explode
		ADDL $4, %ESP
		POPL %EDX
		POPL %ECX
		POPL %EAX

		MOVL EXPLODED(%EBX), %ECX	#Decrement exploded value
		SUBL $1, %ECX
		MOVL %ECX, EXPLODED(%EBX)

		MOVL X(%EBX), %ESI
		MOVL Y(%EBX), %EDI

		#Print the explosion character
		PUSHL %EAX
		PUSHL %ECX
		PUSHL %EDX
		PUSHL %EDI
		PUSHL %ESI
		CALL calc_vid_offset
		MOVB EXPLOSION, %CL
		CALL mp1_poke
		ADDL $8, %ESP
		POPL %EDX
		POPL %ECX
		POPL %EAX

		CMPL $0, %ECX			#check if explosion = 0
		JNE missile_exploding_done

		#Clear the missile's screen location
		MOVL X(%EBX), %ESI
		MOVL Y(%EBX), %EDI
		PUSHL %EAX
		PUSHL %ECX
		PUSHL %EDX
		PUSHL %EDI
		PUSHL %ESI
		CALL calc_vid_offset
		MOVB $32, %CL
		CALL mp1_poke
		ADDL $8, %ESP
		POPL %EDX
		POPL %ECX
		POPL %EAX

		#Delete the missile from the list
		PUSHL %EAX
		PUSHL %ECX
		PUSHL %EDX
		PUSHL %EBX
		CALL delete_missile
		ADDL $4, %ESP
		POPL %EDX
		POPL %ECX
		POPL %EAX

missile_exploding_done:
		POPL %EDI
		POPL %ESI
		POPL %EBX
		LEAVE
		RET

# void missile_moving(struct * missile)
# Local Variables	:	Old X (ebp-4), Old Y (ebp-8)
missile_moving:
		PUSHL %EBP
		MOVL %ESP, %EBP
		ADDL $-8, %ESP
		PUSHL %EBX
		PUSHL %ESI
		PUSHL %EDI

		#Clear old missile location
		MOVL 8(%EBP), %EAX	#Store the pointer in eax
		MOVL X(%EAX), %EBX
		MOVL VX(%EAX), %ECX
		SUBL %ECX, %EBX		#Calculate the old x position
		SHRL $16, %EBX
		MOVL %EBX, -4(%EBP)	#store the old x position

		MOVL Y(%EAX), %EBX
		MOVL VY(%EAX), %ECX
		SUBL %ECX, %EBX		#Calculate the old y position
		SHRL $16, %EBX
		MOVL %EBX, -8(%EBP)	#store the old x position

		PUSHL %EAX 			#Calculate the video offset and print space char
		PUSHL %ECX
		PUSHL %EDX
		PUSHL -8(%EBP)
		PUSHL -4(%EBP)
		CALL calc_vid_offset
		MOVB $32, %CL
		CALL mp1_poke
		ADDL $8, %ESP
		POPL %EDX
		POPL %ECX
		POPL %EAX

		#Print the new missile
		MOVL X(%EAX), %EAX
		SHRL $16, %EAX		#Put the current x position in eax
		MOVL Y(%EAX), %EBX
		SHRL $16, %EBX		#put the current y positino in ebx

		PUSHL %EAX
		PUSHL %ECX
		PUSHL %EDX
		PUSHL %EBX
		PUSHL %EAX
		CALL calc_vid_offset
		MOVB C, %CL
		CALL mp1_poke
		ADDL $8, %ESP
		POPL %EDX
		POPL %ECX
		POPL %EAX

		POPL %EDI
		POPL %ESI
		POPL %EBX
		LEAVE
		RET

# void delete_missiles(struct * targetmissile)
# This function takes a pointer to a missile and deletes the missile
# from the list and then frees the memory it occupied
# Inputs	: struct * targetmissile - pointer to missile to be deleted
# Output	: none
# Registers	: Standard C calling convention

delete_missile:
		PUSHL %EBP
		MOVL %ESP, %EBP
		ADDL $-8, %ESP		#Save space for local variables
		PUSHL %EBX
		PUSHL %ESI
		PUSHL %EDI

		MOVL 8(%EBP), %EAX	#Put the target missile pointer into eax
		MOVL mp1_missile_list, %EBX
		CMP %EBX, %EAX
		JE head_missile		#Check if missile to be deleted is head missile

		MOVL NEXT(%EAX), %EDI
		MOVL %EDI, -4(%EBP)	#Move the after missile pointer into memory

		MOVL mp1_missile_list, %EBX
		MOVL %EBX, -8(%EBP)	#Store the missile before in memory

		#Missile directly afte the target missile is stored in EBP-4
		#missile stored before the target missile is stored in EBP-8

grab_prior_missile:
		MOVL -8(%EBP), %EBX
		MOVL NEXT(%EBX), %EDI
		CMP %EDI, %EAX
		JE got_prior_missile
		MOVL NEXT(%EBX), %EBX
		MOVL %EBX, -8(%EBP)
		JMP grab_prior_missile

got_prior_missile:
		MOVL -4(%EBP), %EBX
		CMP $0, %EBX		#If the after missile is a null pointer,it's the end of the list
		JE tail_missile

middle_missile:
		MOVL -4(%EBP), %EBX	#EBX = after missile
		MOVL -8(%EBP), %ECX	#ECX = before missile
		MOVL %EBX, NEXT(%ECX)
		PUSHL %EAX
		PUSHL %ECX
		PUSHL %EDX
		PUSHL %EAX
		CALL mp1_free
		ADDL $4, %ESP
		POPL %EDX
		POPL %ECX
		POPL %EAX
		JMP delete_done

tail_missile:
		MOVL -8(%EBP), %EBX
		MOVL $0, NEXT(%EBX)
		PUSHL %EAX
		PUSHL %ECX
		PUSHL %EDX
		PUSHL %EAX
		CALL mp1_free
		ADDL $4, %ESP
		POPL %EDX
		POPL %ECX
		POPL %EAX
		JMP delete_done

head_missile:
		MOVL NEXT(%EBX), %ECX
		MOVL %ECX, mp1_missile_list
		PUSHL %EAX
		PUSHL %ECX
		PUSHL %EDX
		PUSHL %EAX
		CALL mp1_free
		ADDL $4, %ESP
		POPL %EDX
		POPL %ECX
		POPL %EAX
		JMP delete_done

delete_done:
		POPL %EDI
		POPL %ESI
		POPL %EBX
		ADD $8, %ESP
		LEAVE
		RET
