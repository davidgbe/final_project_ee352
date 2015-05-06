.data
	#prompts
	ask_for_line_size: .asciiz "Please provide the line size (in bytes): "
	ask_for_lines_per_set: .asciiz "Please provide the number of lines per set: "
	ask_for_cache_size: .asciiz "Please provide a size for the cache (in KB and a multiple of the set size): "
	invalid_cache_size: .asciiz "Cache size was not divisible by set size"
	
	#helpful for printing
	newline: .asciiz "\n"
	
	#data
	main_memory: .word 0 : 65536 #roughly 65KB of storage in main memory
	
.text

main:
	#collect input
	la $t7, ask_for_line_size 
	jal collectInput
	move $s1, $a0
	
	la $t7, ask_for_lines_per_set
	jal collectInput
	move $s2, $a0
	
	mult $s1, $s2
	mflo $s3
	move $t7, $s3
	jal printInt #print set size
	
	la $t7, ask_for_cache_size
	jal collectInput
	move $s0, $a0
	addi $t9, $zero, 1000
	mult $s0, $t9
	mflo $s0
	
	div $s0, $s1
	mflo $s4 #number of lines
	
	move $t7, $s4
	jal printInt #print number of lines
	
	div $s0, $s3
	mfhi $t1 #cache size not divisible by set size
	mflo $s5 #number of sets
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
	move $t7, $s0
	jal printInt #print size of cache with extra size for info
	#dynamic allocation of cache
	li $v0, 9
	move $a0, $s0 #where $s0 has number of bytes to allocate
	syscall
	move $s0, $v0 #$s0 is now the leading address of the cache
	
	move $t8, $s5 #find necessary bits for number of sets
	jal necessaryBits
	move $s7, $t8
	
	move $t7, $t8
	jal printInt
	
	move $t8, $s1 #find necessary bits to specify offset
	jal necessaryBits
	move $a3, $t8
	
	move $t7, $t8
	jal printInt
	
	add $s6, $zero, 32 #calculate tag size
	sub $s6, $s6, $s7
	sub $s6, $s6, $a3 
	move $t7, $s6
	jal printInt #print tag size
	
end:
	#end of program
	li $v0, 10
	syscall
	
findSetForAddress: 
	

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

necessaryBits: #excepts arg to be in $t8, returns in $t8
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
	
	
