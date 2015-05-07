.data	
	#helpful for printing
	newline: .asciiz "\n"
	number_of_accesses_message: .asciiz "Number of accesses in input file: "
	
	#data
	buffer: .space 1400
	access_queue: .word 0:200
	access_queue_size: .word 200
	
	trace_file: 		.asciiz "trace.txt"
	input_error_string:	.ascii  "Error on input \n"
	trace_file_line_length: .word 7
		
.text

main:
	
	
# Open File
open:
	li	$v0, 13		# Open File Syscall
	la	$a0, trace_file	# Load File Name
	li	$a1, 0		# Read-only Flag
	li	$a2, 0		# (ignored)
	syscall
	move	$s6, $v0	# Save File Descriptor
	blt	$v0, 0, err	# Goto Error
 
# Read Data
read:
	li	$v0, 14		# Read File Syscall
	move	$a0, $s6	# Load File Descriptor
	la	$a1, buffer	# Load Buffer Address
	li	$a2, 1400	# Buffer Size
	syscall
	
save_number_of_accesses:

	move $t0, $v0	#save size of file
	
	#get size of access queue (divide size by line_length and add 1, due to trace.txt file format)
	lw $t1, trace_file_line_length($zero)
	div $t0, $t1
	mflo $t1
	addi $t1, $t1, 1
	sw $t1, access_queue_size
	
	li $v0, 4
	la $a0, number_of_accesses_message
	syscall
	
	li $v0 1
	move $a0, $t1
	syscall
	
	li $v0, 4
	la $a0, newline
	syscall
	
	li $t1, 2	#starting point of important info from first address (sets up for loop)
	
loop_through_lines:
	
	jal get_one_line
	addi $t1, $t1, 3				#skip to beginning of address on next line
	blt $t1, $t0, loop_through_lines		#keep iterating until done
	
	b close	
 
 get_one_line: #expects "index" value in t1
 	sub $sp,$sp,4 # push ra
	sw $ra,4($sp)
	
	
	add $t2, $zero, $zero	#reset
	
	#converts a row of 4 ascii char in hex format, and stores them in $t5
	
	lbu $t3, buffer($t1)	#MSBB "bucket"
	jal hexchar_to_int
	addi $t6, $zero, 4096	
	mult $t3, $t6		#16 Cubed
	mflo $t3
	add $t2, $t2, $t3
	
	addi $t1, $t1, 1
	
	lbu $t3, buffer($t1)	#next "bucket"
	jal hexchar_to_int
	addi $t6, $zero, 256
	mult $t3, $t6		#16 Squared
	mflo $t3
	add $t2, $t2, $t3
	
	addi $t1, $t1, 1
	
	lbu $t3, buffer($t1)	#next "bucket"
	jal hexchar_to_int
	addi $t6, $zero, 16
	mult $t3, $t6		#16
	mflo $t3
	add $t2, $t2, $t3
	
	addi $t1, $t1, 1
	
	lbu $t3, buffer($t1)	#LSB "bucket"
	jal hexchar_to_int
	addi $t6, $zero, 1
	mult $t3, $t6		#1
	mflo $t3
	add $t2, $t2, $t3
	
	addi $t1, $t1, 1
	
#	li $v0, 1
#	move $a0, $t2
#	syscall
#	
#	li $v0, 4
#	la $a0, newline
#	syscall
	
	#store converted address in proper location
	lw $t4, trace_file_line_length($zero)
	div $t1, $t4
	mflo $t4
	sll $t4, $t4, 2
	
	sw $t2, access_queue($t4)
	
	lw $ra,4($sp) # pop ra
	add $sp,$sp,4
	jr $ra
 
# Close File
close:
	li	$v0, 16		# Close File Syscall
	move	$a0, $s6	# Load File Descriptor
	syscall
	b	done		# Goto End
 
# Error
err:
	li	$v0, 4			# Print String Syscall
	la	$a0, input_error_string	# Load Error String
	syscall
	b done
 
# Done
done:
	li	$v0, 10		# Exit Syscall
	syscall
	
hexchar_to_int: #expect arg in $t3

        li $t8,0X30
        li $t9,0x39

        andi    $t8,$t8,0x000000ff #Cast to word for comparison.
        andi    $t9,$t9,0x000000ff

        bltu    $t3,$t8,err     #error if lower than 0x30
        bgt     $t3,$t9,dohex     #if greater than 0x39, test for A -F

        addiu   $t3,$t3,-0x30     #OK, char between 48 and 55. Subtract 48.
        jr $ra

dohex:  li      $t8,0x41
        li      $t9,0x46

        andi   $t8,$t8,0x000000ff #Cast to word for comparison.
        andi   $t9,$t9,0x000000ff

        #is byte is between 65 and 70

        bltu    $t3,$t8,err     #error if lower than 0x41
        bgt     $t3,$t9,err     #error if greater than 0x46

ishex:  addiu   $t3,$t3,-0x37     #subtract 55 from hex char ('A'- 'F')
        jr $ra
