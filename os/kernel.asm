; basic BIOS-thing for the CPU

dint                    ; disable interrupts, we don't want them yet
lval 0x00 0xFFFF0000    ; text cursor position is stored in r1
sint 0x10 4             ; define PUTC syscall
;;;;; BEGIN SUBROUTINE: putc ;;;;;
pop 0x01                ; pop retaddr stack->r2
pop 0x40                ; pop char stack->r64
sreg 0x40 0x00          ; store char r64->cursorpos
add 0x00 1              ; increment cursor pos
push 0x01               ; push retaddr r1->stack
rtrn                    ; return to caller
;;;;; END SUBROUTINE: putc ;;;;;
sint 0x11 11            ; define PUTS syscall
;;;;; BEGIN SUBROUTINE: puts ;;;;;
pop 0x02                ; pop retaddr stack->r3
pop 0x3F                ; pop strlen->r63
pop 0x3D                ; pop strstart->r62
lreg 0x3D 0x3C          ; load char mem->r61
push 0x3C               ; push char r61->stack
intr 0x10               ; call PUTC
sub 0x3D 1              ; decrement r63
cmpr 1 0x3D 0           ; compare r63==0?
bneq -5                 ; if NEQ jmp -5, loop
push 0x02               ; push retaddr r2->stack
rtrn                    ; return to caller
;;;;; END SUBROUTINE: puts ;;;;;
str "Welcome to the CPUEMU BIOS."       ; assembler shortcut
intr 0x11               ; call PUTS
halt
