.global _start
.intel_syntax noprefix

_start:
	mov eax, 0x4f # sycall number for getcwd
	sub rsp, 0x1000 # allocate space for cwd - worst case 4096 bytes
	mov rdi, rsp
	mov rsi, 0x1000
	syscall
	mov eax, 0x101 # syscall number for openat
	mov rdi, -100  # AT_FDCWD
	mov rsi, rsp  # '.'/CWD hex value
	mov rdx, 0x0 # O_RDONLY
	xor rdx, 0x800 #  O_NONBLOCK
	xor rdx, 0x80000 # O_CLOEXEC
	xor rdx, 0x10000 # O_DIRECTORY
	syscall
	mov rdi, rax # file descriptor
	mov rax, 0xd9 # syscall number for getdents64
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
	jmp write_results # else write filename to stdout

write_results:
	push rax # save result of getdents64 to restore later
	push rbx # save offset 
	push rcx # save length of record
	mov eax, 0x1 # syscall number for write
	mov rdi, 0x1 # stdout fd
	mov rsi, rdx # filename
	mov rdx, r14 # filename length
	syscall # write filename to stdout
	push 0xa # push newline
	mov eax, 0x1
	mov rdi, 0x1
	mov rsi, rsp
	mov rdx, 0x1
	syscall # write newline to stdout
	pop r11 # pop newline
	pop rcx # restore registers
	pop rbx 
	pop rax
	jmp loop #jmp back to main loop

exit:
	mov rax, 0x3c # syscall number for exit
	mov rdi, 0x0 # exit code
	syscall
