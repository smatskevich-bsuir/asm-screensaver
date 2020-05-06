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
        jb end_timer_interupt

        cmp showing, 0
        jne end_timer_interupt

        mov showing, 1
        mov ticks_counter, 0
        call save_screen
        call banner

        end_timer_interupt:
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
    
        call dword ptr cs:[old_keyboard_handler]

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
        sti

        push cs
        pop ds

        no_input:
        cmp showing, 0
        jne hide_banner
        jmp end_keyboard_interupt

        hide_banner:
        call restore_screen
        mov showing, 0

        end_keyboard_interupt:
        mov ticks_counter, 0
        pop ds
        pop es
        popa
        iret
    keyboard_handler endp

    init:
        mov bx, 10
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

    calc_ticks:
        ;bx - secs
        ;ax - res
        mov ax, 182
        xor dx, dx
        mul bx
        mov bx, 10
        div bx
    ret
end prog