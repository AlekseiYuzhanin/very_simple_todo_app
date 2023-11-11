SYS_read equ 0
SYS_open equ 2
SYS_write equ 1
SYS_exit equ 60
SYS_socket equ 41
SYS_accept equ 43
SYS_bind equ 49
SYS_listen equ 50
SYS_close equ 3
SYS_setsockopt equ 54
SYS_fstat64 equ 5

O_RDONLY = 0
0_WRONLY = 1
0_CREAT = 64
0_TRUNC = 512

AF_INET equ 2
SOCK_STREAM equ 1
INADDR_ANY equ 0

SOL_SOCKET = 1
SO_REUSEADDR = 2
SO_REUSEPORT = 15

SO_TCP = 6
TCP_NODELAY = 1

STDOUT equ 1
STDERR equ 2

EXIT_SUCCESS equ 0
EXIT_FAILURE equ 1

sizeof_stat64 = 144
stat64.st_size = 48

macro funcall2 func, a, b
{
    mov rdi, a
    mov rsi, b
    call func
}

macro funcall3 func, a, b, c
{
    mov rdi, a
    mov rsi, b
    mov rdx, c
    call func
}

macro funcall4 func, a, b, c, d
{
    mov rdi, a
    mov rsi, b
    mov rdx, c
    mov r10, d
    call func
}

macro syscall1 number, a
{
    mov rax, number
    mov rdi, a
    syscall
}

macro syscall2 number, a, b
{
    mov rax, number
    mov rdi, a
    mov rsi, b
    syscall
}

macro syscall3 number, a, b, c
{
    mov rax, number
    mov rdi, a
    mov rsi, b
    mov rdx, c
    syscall
}

macro syscall5 number, a, b, c, d, e
{
    mov rax, number
    mov rdi, a
    mov rsi, b
    mov rdx, c
    mov r10, d
    mov r8, e
    syscall
}

macro write, fd, buf, count
{
    syscall3, SYS_write, fd, buf, count
}

macro read, fd, buf, count
{
    syscall3 SYS_read, fd, buf, count
}

macro close fd
{
    syscall1 SYS_close, fd
}

