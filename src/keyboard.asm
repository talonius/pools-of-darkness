; ZeroFill zero-fills n bytes at s, using word stores after an optional odd byte.  It is linked into GameIo by
; {$L KEYBOARD.OBJ}.
;
; ZeroFill(var s; n: Word); far; retf 6.  It reads its arguments through BX, with no BP frame.
CODE    SEGMENT BYTE PUBLIC             ; no 'CODE' class -> {$L} merges into the unit seg
        ASSUME  CS:CODE
        PUBLIC  ZEROFILL

ZEROFILL       PROC FAR
        mov     bx,sp                   ; the arguments through sp, no push bp
        les     di,ss:[bx+6]            ; ES:DI := @s
        mov     cx,ss:[bx+4]            ; CX := n
        xor     ax,ax                   ; fill value = 0
        cld
        shr     cx,1                    ; words in CX, odd bit -> CF
        jnc     evenlen                 ; even count: skip the lone byte
        stosb                           ; store the odd low byte
        jcxz    done                    ; no whole words left
evenlen:
        rep     stosw
done:
        ret     6                       ; retf 6
ZEROFILL       ENDP
CODE    ENDS
        END
