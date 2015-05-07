.data
	#prompts
	ask_for_line_size: .asciiz "Please provide the line size (in bytes): "
	ask_for_lines_per_set: .asciiz "Please provide the number of lines per set: "
	ask_for_cache_size: .asciiz "Please provide a size for the cache (in KB and a multiple of the set size): "
	invalid_cache_size: .asciiz "Cache size was not divisible by set size"
	number_of_accesses_message: .asciiz "Number of accesses in input file: "
	number_of_sets_text: .asciiz "Number of sets: "
	set_size_text: .asciiz "Size of each set: "
	number_of_lines_text: .asciiz "Number of lines: " 
	size_of_tag_text: .asciiz "Size of tag: " 
	bits_needed_offset_text: .asciiz "Bits needed for offset: "
	bits_needed_sets_text: .asciiz "Bits needed for sets: "
	
	#helpful for printing
	newline: .asciiz "\n"
	test_message: .asciiz "TEST: "
	
	#data
	main_memory: .byte 0 : 65536 #roughly 65KB of storage in main memory
	main_memory_size: .word 65536
	cache: .word 0
	actual_cache_size: .word 0
	virtual_cache_size: .word 0
	line_size: .word 0
	actual_line_size: .word 0
	set_size: .word 0
	actual_set_size: .word 0
	lines_per_set: .word 0
	num_lines: .word 0
	num_sets: .word 0
	offset_size: .word 0
	set_index_size: .word 0
	tag_size: .word 0
	access_queue: .word 0
	access_queue_size: .word 200
	
	#input data
	buffer: .space 1400
	trace_file: 		.asciiz "trace.txt"
	input_error_string:	.ascii  "Error on input \n"
	trace_file_line_length: .word 7
	
	test: .word 536870397
	
.text

main:

open_file:
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
	
	#get size of access queue (divide size by file_line_length and add 1, due to trace.txt file format)
	lw $t1, trace_file_line_length($zero)
	div $t0, $t1
	mflo $t1
	addi $t1, $t1, 1

	sw $t1, access_queue_size
	
	#load the address of a dynamically allocated array with the appropriate size into access_queue
	sll $t2, $t1, 2
	li $v0, 9
	move $a0, $t2
	syscall
	sw $v0, access_queue
	
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
	
# Close File
close_file:

	li	$v0, 16		# Close File Syscall
	move	$a0, $s6	# Load File Descriptor
	syscall

begin_collection:
	#collect input
	la $t7, ask_for_line_size 
	jal collectInput
	move $s1, $a0
	sw $s1, line_size
	
	addi $t0, $s1, 6 #add 6 for actual line size
	sw $t0, actual_line_size
	
	la $t7, ask_for_lines_per_set
	jal collectInput
	move $s2, $a0
	sw $s2, lines_per_set
	
	mult $s1, $s2
	mflo $s3
	sw $s3, set_size

	#move $t7, $s3
	#jal printInt #print set size
	
	addi $t0, $s1, 6
	mult $s2, $t0
	mflo $t0
	sw $t0, actual_set_size
	
	li $v0, 4
	la $a0, set_size_text
	syscall
	move $t7, $t0
	jal printInt #print actual set size
	
	la $t7, ask_for_cache_size
	jal collectInput
	move $s0, $a0
	addi $t9, $zero, 1000
	mult $s0, $t9
	mflo $s0
	sw $s0, virtual_cache_size
	
	div $s0, $s1
	mflo $s4 #number of lines
	sw $s4, num_lines
	
	li $v0, 4
	la $a0, number_of_lines_text
	syscall
	move $t7, $s4
	jal printInt #print number of lines
	
	div $s0, $s3
	mfhi $t1 #cache size not divisible by set size
	mflo $s5 #number of sets
	sw $s5, num_sets
	
	li $v0, 4
	la $a0, number_of_sets_text
	syscall
	move $t7, $s5
	jal printInt #print number of sets
	
	beq $t1, $zero, allocation
	
improper_cache_size: 
	la $t7, invalid_cache_size
	jal printError
	j end
	
allocation:	
	addi $t1, $zero, 6
	mult $t1, $s4 #find amount of extra info to be added for valid bit and tag
	mflo $t1
	add $s0, $s0, $t1 #add an extra 6 bytes for each line for valid bit and tag
	sw $s0, actual_cache_size
	
	#move $t7, $s0
	#jal printInt #print size of cache with extra size for info
	
	#dynamic allocation of cache
	li $v0, 9
	move $a0, $s0 #where $s0 has number of bytes to allocate
	syscall
	move $s0, $v0 #$s0 is now the leading address of the cache
	sw $s0, cache
	
	move $t8, $s5 #find necessary bits for number of sets
	jal necessaryBits
	sw $t8, set_index_size
	move $s7, $t8
	
	li $v0, 4
	la $a0, bits_needed_sets_text
	syscall
	move $t7, $t8
	jal printInt
	
	move $t8, $s1 #find necessary bits to specify offset
	jal necessaryBits
	sw $t8, offset_size
	move $a3, $t8
	
	li $v0, 4
	la $a0, bits_needed_offset_text
	syscall
	move $t7, $t8
	jal printInt
	
	add $s6, $zero, 32 #calculate tag size
	sub $s6, $s6, $s7
	sub $s6, $s6, $a3 
	sw $s6, tag_size
	
	li $v0, 4
	la $a0, size_of_tag_text
	syscall
	move $t7, $s6
	jal printInt #print tag size
	
	
	#get ready for populating main_memory
	move $t0, $zero
	lw $t1, main_memory_size
	la $t2, main_memory
	
fill_main_memory_loop:
	

	add $t3, $t0, $t2	#address of next byte to store
	
	li $t4, 32		#value to store in MM
	div $t0, $t4
	mfhi $t4
	
	sb $t4, ($t3)
	
	addi $t0, $t0, 1
	blt $t0, $t1, fill_main_memory_loop
	
	
	#prepare to enter access_loop
	move $t0, $zero
	lw $t1, access_queue_size

access_loop:
	
	#lw $t2, access_queue
	#sll $t3, $t0, 2
	#add $t2, $t2, $t3
	#li $v0, 1
	#lw $a0, 0($t2)
	#syscall
	
	#li $v0, 4
	#la $a0, newline
	#syscall
	
	addiu $sp, $sp, -8
	sw $t0, 0($sp)
	sw $t1, 4($sp)
	
	jal checkCache
	
	lw $t1, 4($sp)
	lw $t0, 0($sp)
	addiu $sp, $sp, 8
	
	addi $t0, $t0, 1
	
	blt $t0, $t1, access_loop
	
			
	
end:
	#end of program
	li $v0, 10
	syscall
	
findMemory: #expect address at $t8
	addiu $sp, $sp, -8
	sw $ra, ($sp)
	sw $t8, 4($sp)
	jal findTagForAddress #compute tag; store in $s1
	move $s1, $t8
	lw $ra, ($sp)
	lw $t8, 4($sp)
	addiu $sp, $sp, 8
	
	addiu $sp, $sp, -8
	sw $ra, ($sp)
	sw $t8, 4($sp)
	jal findOffsetForAddress #compute offset; store in $s2
	move $s2, $t8
	lw $ra, ($sp)
	lw $t8, 4($sp)
	addiu $sp, $sp, 8
	
	#calculate set address for memory address
	addiu $sp, $sp, -8
	sw $ra, ($sp)
	sw $t8, 4($sp)
	jal getSetAddress
	move $s3, $t8
	lw $ra, ($sp)
	lw $t8, 4($sp)
	addiu $sp, $sp, 8
	
	addiu $sp, $sp, -8
	sw $ra, ($sp)
	sw $t8, 4($sp)
	#check the cache
	move $t6, $s2
	move $t7, $s1
	move $t8, $s3
	jal checkCache #Returns hit or miss in $t6, line address in $t7, data in $t8
	move $t9, $t8
	lw $ra, ($sp)
	lw $t8, 4($sp)
	addiu $sp, $sp, 8
	beq $t6, $zero, cacheMiss
	b cacheHit
	
cacheMiss:
	addiu $sp, $sp, -8
	sw $ra, ($sp)
	sw $t8, 4($sp)
	
	move $t5, $s2
	move $t6, $s1
	move $t7, $8
	move $t8, $s3
	jal fetch
	move $t9, $t8
	
	lw $ra, ($sp)
	lw $t8, 4($sp)
	addiu $sp, $sp, 8
	j memoryFindEnd
cacheHit:
	#line address in $t7, data in $t9
memoryFindEnd:
	jr $ra
	
fetch: #expects offset at $t5, tag at $t6, memory address at $t7, set address $t8. Returns value at $t8
	addiu $sp, $sp, -4
	sw $ra, ($sp)
	jal findLRU #Least Recently Used line now in $t8
	sw $ra, ($sp)
	addiu $sp, $sp, 4
	lw $t2, line_size #fetch line size
	addi $t3, $zero, 1 
	sb $t3, ($t8) #put 1 into validity bit
	sb $t3, 1($t8) #put 1 into number of uses of new line
	sw $t6, 2($t8) #put tag into tag position for line
	move $t0, $zero #incrementor 
	addi $t1, $t8, 5 #first address of data within line
	sub $t7, $t7, $t5 #first address of data within main memory
replaceLoop:
	lb $t4, ($t7) #fetch from from address in MM
	sw $t4, ($t1) #write to cache
	bne $t0, $t5, continueLoop 
	move $t8, $t4 #if inc is equal to offset, save byte to be returned
continueLoop:
	addi $t7, $t7, 1
	addi $t1, $t1, 1
	addi $t0, $t0, 1
	blt $t0, $t2, replaceLoop
finishReplace:
	jr $ra
	
	
findLRU: #expects set address $t8, returns address of line to replace in $t8
	move $t0, $zero
	move $t1, $t8
	lw $t2, lines_per_set
	lw $t3, actual_line_size
findLRULoop:
	beq $t0, $t2, foundLRU
	#check use bit
	lb $t4, 1($t1)
	bne $t0, $zero, compareUseBits
	move $t5, $t4
	move $t8, $t1
compareUseBits:
	bge $t5, $t4, increment
	move $t5, $t4
	move $t8, $t1
increment:
	addi $t0, $t0, 1
	add $t1, $t1, $t3
foundLRU:
	jr $ra
	
checkCache: #expects offset in $t6, tag in $t7, address of set in $t8. Returns hit or miss in $t6, line address in $t7, data in $t8
	add $t0, $zero, $zero
	lw $t1, lines_per_set
	lw $t2, actual_line_size
	move $t3, $t8
matchingTagLoop:
	beq $t0, $t1, noMatch #if we exceed line number per set, there is no match
	lb $t4, ($t3) #load valid byte
	beq $t4, 1, checkTag #if valid byte indicates validity, jump to check the tag
	j incr
checkTag: 
	lw $t5, 2($t3) #load tag
	beq $t5, $t7, match #if desired tag and current tag match, there is a match
incr:
	addi $t0, $t0, 1
	add $t3, $t3, $t2
	j matchingTagLoop
match: 
	lb $t5, 1($t3) #grab use bit, increment it, and store it
	addi $t5, $t5, 1
	sb $t5, 1($t3)
	addi $t6, $t6, 5 #add 5 to offset to account for 6 byte offset for extra info
	add $t8, $t3, $t6 #find byte of interest by offsetting current line by augmented offset
	lb $t8, ($t8) #load byte of interest
	addi $t6, $zero, 1 #indicate match was found
	move $t7, $t4 #return line address
	j matchReturn
noMatch:
	move $t7, $t3
	lb $t8, ($t3)
	add $t6, $zero, $zero
matchReturn: 
	jr $ra

getSetAddress: #expects memory address arg in $t8, returns address of set in $t8
	addiu $sp, $sp, -4
	sw $ra, ($sp)
	jal findSetIndexForAddress
	lw $ra, ($sp)
	addiu $sp, $sp, 4
	lw $t0, actual_set_size
	lw $t1, cache
	mult $t8, $t0
	mflo $t0
	add $t8, $t0, $t1
	jr $ra
	
findSetIndexForAddress: #expects memory arg in $t8, returns set in $t8
	move $t7, $t8
	lw $t8, offset_size
	addiu $sp, $sp, -4
	sw $ra, ($sp)
	jal rightShift
	lw $ra, ($sp)
	addiu $sp, $sp, 4
	lw $t8, set_index_size
	move $t1, $t7
	addi $t7, $zero, 1
	addiu $sp, $sp, -4
	sw $ra, ($sp)
	jal leftShift
	lw $ra, ($sp)
	addiu $sp, $sp, 4
	div $t1, $t7
	mfhi $t8
	jr $ra
	
findTagForAddress: #expects memory arg in $t8, returns tag in $t8
	move $t7, $t8
	lw $t8, offset_size
	lw $t9, set_index_size
	add $t8, $t8, $t9
	addiu $sp, $sp, -4
	sw $ra, ($sp)
	jal rightShift
	lw $ra, ($sp)
	addiu $sp, $sp, 4
	move $t8, $t7
	jr $ra
	
findOffsetForAddress: #expects memory arg in $t8, returns set in $t8
	move $t1, $t8
	lw $t8, offset_size
	addi $t7, $zero, 1
	addiu $sp, $sp, -4
	sw $ra, ($sp)
	jal leftShift
	lw $ra, ($sp)
	addiu $sp, $sp, 4
	div $t1, $t7
	mfhi $t8
	jr $ra

collectInput: #expects arg in $t7
	li $v0, 4
	move $a0, $t7
	syscall #print message
	li $v0,5
	syscall #read an integer
	add $a0, $v0, $zero #collect int now in $a0
	jr $ra
	
printError: #expects arg in $t7
	li $v0, 4
	move $a0, $t7
	syscall #print message
	jr $ra
	
printInt: #expects arg in $t7
	li $v0, 1
	move $a0, $t7
	syscall
	li $v0, 4
	la $a0, newline
	syscall
	jr $ra

necessaryBits: #expects arg to be in $t8, returns in $t8
	add $t9, $zero, 1
	add $t6, $zero, 0
loop:
	bge $t9, $t8, return
	sll $t9, $t9, 1
	addi $t6, $t6, 1
	j loop
return:
	move $t8, $t6
	jr $ra
	
rightShift: #expects arg <toShift> in $t7, and arg <timeToShift> in $t8
	add $t0, $zero, $zero
rightShiftLoop:
	beq $t0, $t8, rightShiftDone
	srl $t7, $t7, 1
	addi $t0, $t0, 1
	j rightShiftLoop
rightShiftDone:
	jr $ra

leftShift: #expects arg <toShift> in $t7, and arg <timesToShift> in $t8
	add $t0, $zero, $zero
leftShiftLoop:
	beq $t0, $t8, leftShiftDone
	sll $t7, $t7, 1
	addi $t0, $t0, 1
	j leftShiftLoop
leftShiftDone:
	jr $ra
	
get_one_line: #expects "index" value in t1

	addi $sp, $sp, -4
	sw $ra, ($sp)
	
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
	
	#store converted address in proper location
	lw $t4, trace_file_line_length($zero)
	div $t1, $t4
	mflo $t4
	sll $t4, $t4, 2
	
	lw $t5, access_queue
	add $t5, $t5, $t4
	sw $t2, ($t5)
	
	lw $ra, ($sp)
	addi $sp, $sp, 4

	jr $ra
	
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
	
# Error
err:
	li	$v0, 4			# Print String Syscall
	la	$a0, input_error_string	# Load Error String
	syscall
	b end
