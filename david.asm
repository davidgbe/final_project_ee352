.data
	#prompts
	ask_for_line_size: .asciiz "Please provide the line size (in bytes): "
	ask_for_lines_per_set: .asciiz "Please provide the number of lines per set: "
	ask_for_cache_size: .asciiz "Please provide a size for the cache (in KB and a multiple of the set size): "
	invalid_cache_size: .asciiz "Cache size was not divisible by set size"
	test_message: .asciiz "TEST: "
	
	#helpful for printing
	newline: .asciiz "\n"
	
	#data
	main_memory: .word 0 : 65536 #roughly 65KB of storage in main memory
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
	
	test: .word 536870397
	
.text

main:
	#collect input
	la $t7, ask_for_line_size 
	jal collectInput
	move $s1, $a0
	sw $s1, line_size
	
	addi $t0, $s1, 5
	sw $t0, actual_line_size
	
	la $t7, ask_for_lines_per_set
	jal collectInput
	move $s2, $a0
	sw $s2, lines_per_set
	
	mult $s1, $s2
	mflo $s3
	sw $s3, set_size
	move $t7, $s3
	jal printInt #print set size
	
	addi $t0, $s1, 5
	mult $s2, $t0
	mflo $t0
	sw $t0, actual_set_size
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
	
	move $t7, $s4
	jal printInt #print number of lines
	
	div $s0, $s3
	mfhi $t1 #cache size not divisible by set size
	mflo $s5 #number of sets
	sw $s5, num_sets
	move $t7, $s5
	jal printInt #print number of sets
	
	beq $t1, $zero, allocation
	
improper_cache_size: 
	la $t7, invalid_cache_size
	jal printError
	j end
	
allocation:	
	addi $t1, $zero, 5
	mult $t1, $s4 #find amount of extra info to be added for valid bit and tag
	mflo $t1
	add $s0, $s0, $t1 #add an extra 5 bytes for each line for valid bit and tag
	sw $s0, actual_cache_size
	move $t7, $s0
	jal printInt #print size of cache with extra size for info
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
	
	move $t7, $t8
	jal printInt
	
	move $t8, $s1 #find necessary bits to specify offset
	jal necessaryBits
	sw $t8, offset_size
	move $a3, $t8
	
	move $t7, $t8
	jal printInt
	
	add $s6, $zero, 32 #calculate tag size
	sub $s6, $s6, $s7
	sub $s6, $s6, $a3 
	sw $s6, tag_size
	move $t7, $s6
	jal printInt #print tag size
	
	lw $s0, test #print calculate set address
	move $t8, $s0
	jal checkCache
	move $t0, $t7
	move $t7, $t6
	jal printInt
	move $t7, $t0
	jal printInt
	move $t7, $t8
	jal printInt
	
end:
	#end of program
	li $v0, 10
	syscall
	
	
	

checkCache: #expects address at $t8. Returns hit/miss in $t6, line address in $t7, and data $t8
	move $s4, $ra
	move $s0, $t8 #move the address
	
	jal findTagForAddress #compute tag
	move $s1, $t8
	
	move $t8, $s0 #compute offset
	jal findOffsetForAddress
	move $s2, $t8
	
	move $t8, $s0 #fetch matching set address
	jal getSetAddress
	
	move $t6, $s2
	move $t7, $s1
	jal checkForMatchingTags

	move $ra, $s4
	jr $ra
	
checkForMatchingTags: #expects offset in $t6, tag in $t7, address of set in $t8. Returns hit or miss in $t6, line address in $t7, data in $t8
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
	lw $t5, 1($t3) #load tag
	beq $t5, $t7, match #if desired tag and current tag match, there is a match
incr:
	addi $t0, $t0, 1
	add $t3, $t3, $t2
	j matchingTagLoop
match: 
	addi $t6, $t6, 5 #add 5 to offset to account for extra info
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
	sw $ra, ($sp)
	jal rightShift
	lw $ra, ($sp)
	move $t8, $t7
	jr $ra
	
findOffsetForAddress: #expects memory arg in $t8, returns set in $t8
	move $t1, $t8
	lw $t8, offset_size
	addi $t7, $zero, 1
	sw $ra, ($sp)
	jal leftShift
	lw $ra, ($sp)
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