.286
.model tiny
.code
org 100h
prog:
    jmp init

    screen_buffer dw 2000 dup(0001011100100000b)
    screen_size equ 4000
    showing db 0
    old_timer_handler dd 0
    old_keyboard_handler dd 0
    ticks_target dw 0
    ticks_counter dw 0

    banner_text db    '                                                                                '
                db    '    .d8888b.  888                            d8b                                ' 
                db    '   d88P  Y88b 888                            Y8P                                ' 
                db    '   Y88b.      888                                                               ' 
                db    '    "Y888b.   888  .d88b.   .d88b.  88888b.  888 88888b.   .d88b.               ' 
                db    '       "Y88b. 888 d8P  Y8b d8P  Y8b 888 "88b 888 888 "88b d88P"88b              ' 
                db    '         "888 888 88888888 88888888 888  888 888 888  888 888  888              ' 
                db    '   Y88b  d88P 888 Y8b.     Y8b.     888 d88P 888 888  888 Y88b 888 d8b d8b d8b  ' 
                db    '    "Y8888P"  888  "Y8888   "Y8888  88888P"  888 888  888  "Y88888 Y8P Y8P Y8P  ' 
                db    '                                    888                        888              ' 
                db    '                                    888                   Y8b d88P              ' 
                db    '                                    888                    "Y88P"               ' 
    banner_height equ 12
    banner_size equ 80 * banner_height

    string_buf db 256 dup(0)
    base dw 10

    bad_args_msg db 'Wrong arguments', 10, 13, 'Use: saver.com wait_time$'
    bad_num_msg  db 'Wait time should be in [1, 32767]$'
    endl         db 10, 13, '$'

    save_screen proc
        pusha
        push es
        push 0B800h
        pop es

        xor di, di       
        save_screen_loop:         
        
            mov bx, es:[di]
            mov [screen_buffer + di], bx       
                
        add di, 2
        cmp di, screen_size
        jl save_screen_loop  

        pop es
        popa
        ret
    save_screen endp

    restore_screen proc
        pusha
        push es
        push 0B800h
        pop es

        xor di, di       
        restore_screen_loop:         
        
            mov bx, [screen_buffer + di]
            mov es:[di], bx       
                
        add di, 2
        cmp di, screen_size
        jl restore_screen_loop  

        pop es
        popa
        ret
    restore_screen endp

    banner proc
        pusha
        push es
        push 0B800h
        pop es

        ;fill blue
        xor di, di       
        fill_screen_loop:         
        
            mov BYTE PTR es:[di], ' '
            mov BYTE PTR es:[di + 1], 00010111b       
                
        add di, 2
        cmp di, screen_size
        jl fill_screen_loop

        xor di, di
        xor si, si      
        draw_banner_loop:         

            mov bh, cs:[banner_text + si]
            mov BYTE PTR es:[di], bh
            mov BYTE PTR es:[di + 1], 00010111b       

        add si, 1        
        add di, 2
        cmp si, banner_size
        jl draw_banner_loop

        pop es
        popa
        ret
    banner endp

    timer_handler proc far
        push ds
        push cs
        pop ds
        pushf
        
        call dword ptr cs:old_timer_handler

        pusha

        mov ax, ticks_counter
        inc ax
        mov ticks_counter, ax
        cmp ax, ticks_target
        jb end_timer_interrupt

        cmp showing, 0
        jne end_timer_interrupt

        mov showing, 1
        mov ticks_counter, 0
        call save_screen
        call banner

        end_timer_interrupt:
        popa
        pop ds
        iret
    timer_handler endp

    keyboard_handler proc far
        pusha
        push es
        push ds
        push cs
        pop ds
        pushf
    
        call dword ptr cs:old_keyboard_handler

        cli
            mov ah, 11h
            int 16h
            jz no_input

            cmp al, 1Bh
            jne no_input

            ;restore handlers
            mov ds, WORD PTR cs:old_timer_handler + 2
            mov dx, WORD PTR cs:old_timer_handler
            mov al, 1Ch
            mov ah, 25h
            int 21h 

            mov ds, WORD PTR cs:old_keyboard_handler + 2
            mov dx, WORD PTR cs:old_keyboard_handler
            mov al, 09h
            mov ah, 25h
            int 21h 

            push cs
            pop ds

            no_input:
        sti
        
        cmp showing, 0
        jne hide_banner
        jmp end_keyboard_interrupt

        hide_banner:
        call restore_screen
        mov showing, 0

        end_keyboard_interrupt:
        mov ticks_counter, 0
        pop ds
        pop es
        popa
        iret
    keyboard_handler endp

    init:
        mov bl, cs:[80h] ;args line length 
        add bx, 80h      ;args line last    
        mov si, 82h      ;args line start
        mov di, offset cs:string_buf

        cmp si, bx
        ja bad_arguments
        
        parse_num:
            cmp BYTE PTR es:[si], ' ' 
            je parsed_num 
                
            mov al, es:[si]
            mov [di], al      
                
            inc di
            inc si
        cmp si, bx
        jbe parse_num

        parsed_num:
        push 0
        mov di, offset cs:string_buf 
        push di
        mov di, offset cs:ticks_target 
        push di
        call atoi
        pop ax    
        pop ax 
        pop ax;error

        cmp ax, 1
        je bad_number

        cmp ticks_target, 1
        jl bad_number

        mov bx, ticks_target
        call calc_ticks
        mov ticks_target, ax

        cli
            mov al, 1Ch
            mov ah, 35h
            int 21h 

            mov WORD PTR cs:old_timer_handler, bx
            mov WORD PTR cs:old_timer_handler + 2, es

            mov dx, offset timer_handler
            mov al, 1Ch
            mov ah, 25h
            int 21h 

            mov al, 09h
            mov ah, 35h
            int 21h 

            mov WORD PTR cs:old_keyboard_handler, bx
            mov WORD PTR cs:old_keyboard_handler + 2, es

            mov dx, offset keyboard_handler
            mov al, 09h
            mov ah, 25h
            int 21h 
        sti   
        
        ;resident:
        mov dx, offset init
        int 27h 

        exit:
        mov ax, 4C00h
        int 21h

        bad_arguments:
        mov ax, offset bad_args_msg 
        push ax
        call print_str  
        pop ax
        jmp exit

        bad_number:
        mov ax, offset bad_num_msg 
        push ax
        call print_str  
        pop ax
        jmp exit

    calc_ticks:
        ;bx - secs
        ;ax - res
        mov ax, 182
        xor dx, dx
        mul bx
        mov bx, 10
        div bx
    ret

    ;first - result code, second - string start, third - 16-bit number address
    atoi:   
        push bp
        mov bp, sp   
        pusha        
        
        ;[ss:bp+4+0] - number address  
        ;[ss:bp+4+2] - string address 
        ;[ss:bp+4+4] - error if 1
        mov di, [ss:bp+4+2]  
        
        xor bx, bx     
        xor ax, ax   
        xor cx, cx
        xor dx, dx
        
        cmp BYTE PTR [di + bx], '-'
            jne atoi_loop
        
        inc cx; set negative after loop  
        inc bx
            
        ;parse until error
        atoi_loop:    
            
            cmp BYTE PTR [di + bx], '0'    
            jb atoi_error 
            cmp BYTE PTR [di + bx], '9'    
            ja atoi_error
                                
            mul base 
            mov dh, 0
            mov dl, [di + bx] 
            sub dl, '0'  
            add ax, dx  
            jo atoi_error      
        
        inc bx 
        cmp BYTE PTR [di + bx], 0
        jne atoi_loop  
        
        jmp atoi_result 
        
        atoi_error:
            mov BYTE PTR [ss:bp+4+4], 1    
            jmp atoi_end 
        
        atoi_result:
            mov BYTE PTR [ss:bp+4+4], 0  
            cmp cx, 1
            jne atoi_end
            neg ax
        
        atoi_end: 
            mov di, [ss:bp+4+0]
            mov [di], ax 
        
        popa
        pop bp
    ret 

    print_str:     
        push bp
        mov bp, sp   
        pusha 
        
        mov dx, [ss:bp+4+0]     
        mov ax, 0900h
        int 21h 
        
        mov dx, offset endl
        mov ax, 0900h
        int 21h  
        
        popa
        pop bp      
    ret  
end prog