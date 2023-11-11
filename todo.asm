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
    accept [sockfd], cliaddr.sin_family cliaddr_len
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

    jmp .server_error_405

.handle_get_method:
    add [request_cur], get_len
    sub [request_len], get_len

    funcall4 starts_with, [request_cur], [request_len], index_route, index_route_len
    call starts_with
    cmp rax, 0
    jg .serve_index_page

    jmp .server_error_404

.handle_post_method:
    add [request_cur], post_len
    sub [request_len], post_len

    funcall4 starts_with, [request_cur], [request_len], index_route, index_route_len
    cmp rax, 0
    jg .process_add_or_delete_todo_post

    funcall4 starts_with, [request_cur], [request_len], shutdown_route, shutdown_route_len
    cmp rax, 0
    jg .process_shutdown

    jg .server_error_404

.process_shutdown:
    funcall2 write_cstr, [connfd], shutdown_response
    jmp .shutdown

.process_add_or_delete_todo_post:
    call drop_http_header
    cmp rax, 0
    je .server_error_400

    funcall4 starts_with, [request_cur], [request_len], todo_form_data_prefix, todo_form_data_prefix_len
    cmp rax, 0
    jg .add_new_todo_and_serve_index_page

    funcall4 starts_with, [request_cur], [request_len], delete_form_data_prefix, delete_form_data_prefix_len
    cmp rax, 0
    jg .delete_todo_and_serve_index_page

    jmp .server_error_400

