; VGA-frame XOR and RLE expansion, linked into VgaFrame by {$L VGAFRAME.OBJ}.  Both procedures are far and remove
; their arguments.  ExpandRleFrame's length is the encoded input size, and it checks that bound only between packets:
; malformed input can overread the source within its final packet, and nothing bounds the decoded output, so it can
; also overrun the destination.
CODE    SEGMENT BYTE PUBLIC
        ASSUME  CS:CODE
        PUBLIC  XORFRAME
        PUBLIC  EXPANDRLEFRAME

RLE_LITERAL_MAX EQU     7fh             ; token + 1 literal bytes
RLE_COUNT_BASE  EQU     100h            ; 257 - token repeated bytes

XORFRAME PROC FAR
        push    bp
        mov     bp,sp
        cld
        mov     dx,ds
        les     si,[bp+10h]
        mov     cx,[bp+6]
        mov     bx,0
        mov     ax,0
xorLoop:
        mov     al,es:[bx+si]
        lds     di,[bp+8]
        xor     al,[bx+di]
        lds     di,[bp+0ch]
        mov     [bx+di],al
        inc     bx
        loop    xorLoop
        mov     ds,dx
        pop     bp
        ret     0eh
XORFRAME ENDP

EXPANDRLEFRAME PROC FAR
        push    bp
        mov     bp,sp
        cld
        mov     dx,ds
        lds     si,[bp+0ch]
        les     di,[bp+8]
        mov     bx,0
        mov     ax,0
expandLoop:
        cmp     bx,[bp+6]
        jae     expandDone
        cmp     byte ptr [si],RLE_LITERAL_MAX
        ja      repeatRun
        mov     al,[si]
        add     bx,ax
        inc     bx
        inc     bx
        mov     cx,ax
        inc     cx
        inc     si
        rep     movsb
        jmp     expandLoop
repeatRun:
        inc     bx
        inc     bx
        mov     cx,RLE_COUNT_BASE
        mov     al,[si]
        sub     cx,ax
        inc     cx
        inc     si
        lodsb
        rep     stosb
        jmp     expandLoop
expandDone:
        mov     ds,dx
        pop     bp
        ret     0ah
EXPANDRLEFRAME ENDP
CODE    ENDS
        END
