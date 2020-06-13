dint                    ; disable interrupts
lval 0xFFFF03C9 0       ; max screen char
lval 0 3                ; current char to show
lval 0xFFFF0000 1       ; current screen char
add  3 1                ; increment current char
sreg 3 1                ; store current char at current screen char
add  1 1                ; increment current screen char
cmpr 0 1                ; check if we're at the max screen char
breq 3                  ; if equal to max screen char, jump to instruction 3
brgt 3                  ; if greater than max screen char, jump to instruction 3
jump 4                  ; jump to instruction 4
