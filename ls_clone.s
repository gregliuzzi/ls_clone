#--------------- CONSTANTS -------------#
.set READ_SYSCALL, 0x0
.set WRITE_SYSCALL, 0x1
.set OPENAT_SYSCALL, 0x101
.set GETCWD_SYSCALL, 0x4f
.set GETDENTS64_SYSCALL, 0xd9
.set STATX_SYSCALL, 0x14c
.set EXIT_SYSCALL, 0x3c
.set STDIN_FD, 0x0
.set STDOUT_FD, 0x1

.set AT_FDCWD, -100
.set O_RDONLY, 0x0
.set O_NONBLOCK, 0x800
.set O_CLOEXEC, 0x80000
.set O_DIRECTORY, 0x1000
.set WRITEBUFLEN, 4096
.set STATBUFLEN, 58
.set ITOABUFLEN, 11
.set DT_DIR, 0x4
.set DT_REG, 0x8
.set EPERM, 0x1
.set ENOENT,0x2
.set EACCES, 0xd
#-------------- DATA--------------#

.data

ansi_directory_color_start:
	.string "\x1b[44m"
	len_ansi_directory_color_start = . - ansi_directory_color_start

ansi_directory_color_end:
	.string "\x1b[0m"
	len_ans_directory_color_end = . - ansi_directory_color_end

eperm:
	.string "lxx64: Operation not permitted"
	len_eperm = . - eperm
enoent:
	.string "lsx64: No such file or directory"
	len_enoent = . - enoent
eacces:
	.string "lsx64: Permission denied"
	len_eacces = . - eacces

cwd:
	.string "."

newline_str:
	.string "\n"

fourspace_str:
	.string "    "

total_str:
	.string "total "

output_buf:
	.space WRITEBUFLEN + 1
	.set buf_end, output_buf + WRITEBUFLEN - 1

stat_buf:
	.space STATBUFLEN
	.set stat_buf_end, stat_buf + STATBUFLEN

itoa_buf:
	.space ITOABUFLEN +1
	.set ito_buf_end, itoa_buf + ITOABUFLEN - 1

#--------------MAIN--------------#
.global _start
.intel_syntax noprefix
.text
_start:

	mov rbx, [rsp]
	cmp rbx, 0x1
	jle no_argv
	mov rsi, [rsp+0x10]
	jmp pre_loop
no_argv:
	lea rsi, [cwd]
pre_loop:	
	mov eax, OPENAT_SYSCALL 
	mov rdi, AT_FDCWD  
	mov rdx, O_RDONLY 
	xor rdx, O_NONBLOCK
	xor rdx, O_CLOEXEC 
	xor rdx, O_DIRECTORY
	syscall
	cmp rax, 0x0
	jl .L_open_at_handler
	mov rdi, rax # file descriptor
	mov rax, GETDENTS64_SYSCALL 
	sub rsp, 0x1000
	mov rsi, rsp # buff to write to
	syscall
	cmp rax, 0x0
	jl .L_error_condition
	mov rbx, rsp # offset in buffer
	xor rcx, rcx # length of current linux_dirent
	xor rdx, rdx # filename (null-terminated)
	xor r8, r8 # inode number
	xor r9, r9 # offset to next linux_dirent
	xor r12, r12 # zero padding byte 
	xor r13, r13 # file type 
	xor r14, r14
	xor rdi, rdi	
	lea rsi, output_buf
	xor r15, r15
	jmp loop

.L_open_at_handler:
	mov r12, rax
	neg r12
	mov rax, 0x1
	mov rdi, 0x1
	cmp r12, EPERM
	je .L_eperm
	cmp r12, ENOENT
	je .L_enoent
	cmp r12, EACCES
	je .L_eacces
	jmp exit

.L_eperm:
	lea rsi, [eperm]
	mov rdx, len_eperm
	syscall
	jmp .L_error_condition
.L_enoent:
	lea rsi, [enoent]
	mov rdx, len_enoent
	syscall
	jmp .L_error_condition
.L_eacces:
	lea rsi, [eacces]
	mov rdx, len_eacces
	syscall
	jmp .L_error_condition

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
	je write_results # if offset == buffer length (bytes returned by getdents), exit
	xor rdi, rdi
	jmp update_buffer # else write filename to stdout

get_file_info:
mov rax, STATX_SYSCALL
mov rdi, AT_FDCWD

update_buffer:
	.set IS_DIRECTORY, 0x1
	push rcx
	xor rcx, rcx
	cmp r13, DT_DIR
	je .L_is_directory_start
	jmp insert_bytes

.L_is_directory_start:
	mov r11, IS_DIRECTORY
	lea r10, [ansi_directory_color_start]	
	jmp .L_write_loop_start

.L_is_directory_end:
	xor r11, r11
	lea r10, [ansi_directory_color_end]
	jmp .L_write_loop_end

.L_write_loop_start:	
	mov cl, byte ptr [r10]
	cmp cl, 0x0
	je insert_bytes
	mov [rsi], cl
	inc rsi
	inc rdi
	inc r10
	jmp .L_write_loop_start

.L_write_loop_end:	
	mov cl, byte ptr [r10]
	cmp cl, 0x0
	je restore_registers
	mov [rsi], cl
	inc rsi
	inc rdi
	inc r10
	jmp .L_write_loop_end

insert_bytes:
	mov cl, byte ptr [rdx]
	cmp cl, 0x0
	je restore_registers
	mov [rsi], cl
	inc rsi
	inc rdx
	inc rdi
	jmp insert_bytes

restore_registers:
	cmp r11, 0x1
	je .L_is_directory_end		
	mov cl, [fourspace_str]
	mov [rsi], cl
	pop rcx
	inc rsi
	add rdi, 0x4
	add r15, rdi
	jmp loop

write_results:
	mov rax, WRITE_SYSCALL
	mov rdx, r15
	lea rsi, output_buf
	mov rdi, STDOUT_FD
	syscall
	cmp rax, 0x0
	jl .L_error_condition
	jmp .L_success_condition

.L_error_condition:
	mov rdi, 0x1 # set exit number to 1 to indicate error
	jmp exit

.L_success_condition:
	mov rdi, 0x0
	jmp exit
	
exit:
	mov rax, EXIT_SYSCALL  # syscall number for exit
	syscall
