format ELF64 executable

include "linux.inc"

MAX_CONN equ 5
REQUEST_CAP equ 128*1024
TODO_SIZE equ 256
TODO_CAP equ 256

segment readable executable

include "utils.inc"

entry main
main:
    call load_todos

    funcall2 write_cstr, STDOUT, start
    socket AF_INET, SOCK_STREAM, 0
    cmp rax, 0
    jl .fatal_error
    mov qword [sockfd], rax

    setsockopt [sockfd], SOL_SOCKET, SO_REUSEADDR, enable, 4
    cmp rax, 0
    jl .fatal_error

    setsockopt [sockfd], SOL_SOCKET, SO_REUSEPORT, enable, 4
    cmp rax, 0
    jl .fatal_error

    funcall2 write_cstr, STDOUT, bind_trace_msg
    mov word [servaddr.sin_family], AF_INET
    mov word [servaddr.sin_port], 14619
    mov dword [servaddr.sin_addr], INADDR_ANY
    cmp rax, 0
    jl .fatal_error

    funcall2 write_cstr, STDOUT, listen_trace_msg
    listen [sockfd], MAX_CONN
    cmp rax, 0
    jl .fatal_error

.next_request:
    funcall2 write_cstr STDOUT, accept_trace_msg
    accept [sockfd], cliaddr.sin_family 
    cmp rax, 0
    jl .fatal_error

    mov qword [connfd], rax

    read [connfd], request, REQUEST_CAP
    cmp rax, 0
    jl .fatal_error
    mov [request_len], rax

    mov [request_cur], request

    write STDOUT, [request_cur], [request_len]

    funcall4 starts_with, [request_cur], [request_len], get, get_len
    cmp rax, 0
    jg .handle_get_method

    funcall4 starts_with, [request_cur], [request_len], post, post_len
    cmp rax, 0
    jg .handle_post_method

    jmp .serve_error_405

.handle_get_method:
    add [request_cur], get_len
    sub [request_len], get_len

    funcall4 starts_with, [request_cur], [request_len], index_route, index_route_len
    call starts_with
    cmp rax, 0
    jg .serve_index_page

    jmp .serve_error_404

.handle_post_method:
    add [request_cur], post_len
    sub [request_len], post_len

    funcall4 starts_with, [request_cur], [request_len], index_route, index_route_len
    cmp rax, 0
    jg .process_add_or_delete_todo_post

    funcall4 starts_with, [request_cur], [request_len], shutdown_route, shutdown_route_len
    cmp rax, 0
    jg .process_shutdown

    jg .serve_error_404

.process_shutdown:
    funcall2 write_cstr, [connfd], shutdown_response
    jmp .shutdown

.process_add_or_delete_todo_post:
    call drop_http_header
    cmp rax, 0
    je .serve_error_400

    funcall4 starts_with, [request_cur], [request_len], todo_form_data_prefix, todo_form_data_prefix_len
    cmp rax, 0
    jg .add_new_todo_and_serve_index_page

    funcall4 starts_with, [request_cur], [request_len], delete_form_data_prefix, delete_form_data_prefix_len
    cmp rax, 0
    jg .delete_todo_and_serve_index_page

    jmp .serve_error_400

serve_index_page:
    funcall2 write_cstr, [connfd], index_page_response
    funcall2 write_cstr, [connfd], index_page_header
    call render_todos_as_html
    funcall2 write_cstr, [connfd], index_page_footer
    close [connfd]
    jmp .next_request

.serve_error_400:
    funcall2 write_cstr, [connfd], error_400
    close [connfd]
    jmp .next_request

.serve_error_404:
    funcall2 write_cstr, [connfd], error_404
    close [connfd]
    jmp .next_request

.serve_error_405:
    funcall2 write_cstr, [connfd], error_405
    close [connfd]
    jmp .next_request

.add_new_todo_and_serve_index_page:
    add [request_cur], todo_form_data_prefix_len
    sub [request_len], todo_form_data_prefix_len

    funcall2 add_todo, [request_cur], [request_len]
    call save_todos
    jmp .serve_index_page

.delete_todo_and_serve_index_page:
    add [request_cur], delete_form_data_prefix_len
    sub [request_len], delete_form_data_prefix_len

    funcall2 parse_uint, [request_cur], [request_len]
    mov rdi, rax
    call delete_todo
    call save_todos
    jmp .serve_index_page

.shutdown:
    funcall2 write_cstr, STDOUT, ok_msg
    close [connfd]
    close [sockfd]
    exit 0

.fatal_error:
    funcall2 write_cstr, STDERR, ok_msg
    close [connfd]
    close [sockfd]
    exit 0

.drop_http_header:
.next_line:
    funcall4 starts_with, [request_cur], [request_len], clrs, 2
    cmp rax, 0
    jg .reached_end

    funcall3 find_char, [request_cur], [request_len], 10
    cmp rax, 0
    je .invalid_header

    mov rsi, rax
    sub rsi, [request_cur]
    inc rsi
    add [request_cur], rsi
    sub [request_len], rsi

    jmp .next_line

.reached_end:
    add [request_cur], 2
    sub [request_len], 2
    mov rax, 1
    ret

.invalid_header:
    xor rax, rax
    ret

.delete_todo:
    mov rax, TODO_SIZE
    mul rdi
    cmp rax, [todo_end_offset]
    jge .overflow

    mov rdi, todo_begin
    add rdi, rax
    mov rsi, todo_begin
    add rsi, rax
    mov rdx, TODO_SIZE
    add rdx, [todo_end_offset]
    sub rdx, rsi
    call memcpy

    sub [todo_end_offset], TODO_SIZE

.overflow:
    ret

load_todos:
    sub rsp, 16
    mov qword [rsp+8], -1
    mov qword [rsp], 0

    open todo_db_file_path, O_RDONLY, 0
    cmp rax, 0
    jl .error
    mov [rsp+8], statbuf
    
    fstat64 [rsp+8], statbuf
    cmp rax, 0
    jl .error

    mov rax, statbuf
    add rax, stat64.st_size
    mov rax, [rax]
    mov [rsp], rax

    mov rcx, TODO_SIZE
    div rcx
    cmp rdx, 0
    jne .error

    mov rcx, TODO_CAP*TODO_SIZE
    mov rax, [rsp]
    cmp rax, rcx
    cmovg rax, rcx
    mov [rsp], rax

    read [rsp+8], todo_begin, [rsp]
    mov rax, [rsp]
    mov [todo_end_offset], rax

.error:
    close [rsp+8]
    add rsp, 16
    ret

save_todos:
    