#--------------- CONSTANTS -------------#
.set READ_SYSCALL, 0x0
.set WRITE_SYSCALL, 0x1
.set OPENAT_SYSCALL, 0x101
.set GETCWD_SYSCALL, 0x4f
.set GETDENTS64_SYSCALL, 0xd9
.set EXIT_SYSCALL, 0x3c
.set STDIN_FD, 0x0
.set STDOUT_FD, 0x1

.set AT_FDCWD, -100
.set O_RDONLY, 0x0
.set O_NONBLOCK, 0x800
.set O_CLOEXEC, 0x80000
.set O_DIRECTORY, 0x1000
.set WRITEBUFLEN, 4096

#-------------- DATA--------------#

.data

newline_str:
	.string "\n"

fourspace_str:
	.string "    "

total_str:
	.string "total "

buf_for_read:
	.space WRITEBUFLEN + 1
	.set buf_end, buf_for_read + WRITEBUFLEN - 1

#--------------MAIN--------------#
.global _start
.intel_syntax noprefix
.text
_start:
	mov eax, GETCWD_SYSCALL 
	sub rsp, 0x1000 # allocate space for cwd - worst case 4096 bytes
	mov rdi, rsp
	mov rsi, 0x1000
	syscall
	mov eax, OPENAT_SYSCALL 
	mov rdi, AT_FDCWD  
	mov rsi, rsp  # '.'/CWD hex value
	mov rdx, O_RDONLY 
	xor rdx, O_NONBLOCK
	xor rdx, O_CLOEXEC 
	xor rdx, O_DIRECTORY
	syscall
	mov rdi, rax # file descriptor
	mov rax, GETDENTS64_SYSCALL 
	sub rsp, 0x1000
	mov rsi, rsp # buff to write to
	syscall
	cmp rax, 0x0
	je exit 
	mov rbx, rsp # offset in buffer
	xor rcx, rcx # length of current linux_dirent
	xor rdx, rdx # filename (null-terminated)
	xor r8, r8 # inode number
	xor r9, r9 # offset to next linux_dirent
	xor r12, r12 # zero padding byte 
	xor r13, r13 # file type 
	xor r14, r14
	xor rdi, rdi	
	lea rsi, [buf_end]
	xor r15, r15
loop:
# struct linux_dirent {
# unsigned long d_ino
# unsigned long d_off
# unsigned short d_reclen
# char d_type
# char d_name[]
# }
	add rbx, rcx # move to next dirent structure offset
	add r12, rcx # update current offset
	mov r8, qword ptr [rbx] # mov d_ino into r8
	mov r9, qword ptr [rbx+0x8] # mov d_off into r9
	mov cx, word ptr [rbx+0x10] # mov d_reclen into rcx
	mov r13b, byte ptr [rbx+0x12] # mov d_type into r13
	mov r14, rcx # calculate length of filename
	sub r14, 0x13
	lea rdx, [rbx+0x13] # mov d_name into rdx
	cmp r12, rax # check offset against end of buffer
	je exit # if offset == buffer length (bytes returned by getdents), exit
	xor rdi, rdi
	jmp update_buffer # else write filename to stdout

update_buffer:
	push rcx
	push rdx
	xor rcx, rcx
	jmp find_null_byte

find_null_byte:
	mov cl, byte ptr [rdx]
	cmp cl, 0x0
	je update_string_length
	inc rdx
	inc rdi
	jmp find_null_byte

update_string_length:
	pop rdx
	mov r14, rdi
	sub r14, 0x1
	xor rdi, rdi
	add rdx, r14
	jmp insert_bytes

insert_bytes:
	mov cl, byte ptr [rdx]
	cmp cl, 0x0
	je restore_registers
	sub rsi, 0x1
	mov [rsi], cl
	dec rdx
	inc rdi
	jmp insert_bytes

restore_registers:
	mov cl, [newline_str]
	mov [rsi], cl	
	pop rcx
	dec rsi
	inc rdi
	add r15, rdi
	jmp loop
	
exit:
	mov rax, WRITE_SYSCALL
	mov rdx, r15
	lea rsi, [buf_end]
	sub rsi, r15
	mov rdi, STDOUT_FD
	syscall
	mov rax, EXIT_SYSCALL  # syscall number for exit
	mov rdi, 0x0 # exit code
	syscall
