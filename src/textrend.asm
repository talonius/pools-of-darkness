; The three glyph blitters RenderChar dispatches to, one per display class, linked into TextRend's code
; segment by {$L TEXTREND.OBJ}.  Each draws one 8x8 glyph into text cell (col, row), in color fg where a glyph bit is
; set and bg where it is clear.
;
; EGAGLYPH and TANDYGLYPH are near (`ret 0Ah`) and VGAGLYPH is far (`retf 0Ah`), so textrend.pas declares
; the first two under {$F-} and the third under {$F+}.  The EGA and Tandy blitters draw the eight rows RenderChar stages
; in glyphRowBuf and never read `glyph`; the MCGA blitter reads the glyph from the font through gameFont itself.
;
; The arguments are in Pascal order (col, row: Word; fg, bg, glyph: Byte), the last nearest bp.

DGROUP  GROUP   DATA                    ; gameFont and glyphRowBuf live in the data segment
DATA    SEGMENT WORD PUBLIC
        EXTRN   GAMEFONT:DWORD           ; far pointer to the font, 8 bytes a glyph
        EXTRN   GLYPHROWBUF:BYTE        ; the 8 rows of the glyph, staged by RenderChar
DATA    ENDS

CODE    SEGMENT BYTE PUBLIC             ; no class, so {$L} merges it into the unit's segment
        ASSUME  CS:CODE, DS:DGROUP
        PUBLIC  EGAGLYPH
        PUBLIC  TANDYGLYPH
        PUBLIC  VGAGLYPH

; ---------------------------------------------------------------------------
; EGAGLYPH -- EGA planar, through the Graphics Controller in write mode 2, read mode 1.  For each glyph row it
; sets Bit Mask to the row's bits and writes fg into the cell byte, then sets the complement and writes bg; each
; write is a read-modify-write, whose read loads the latches.  40 bytes per scanline.  The Graphics Controller is
; left in its defaults.
; ---------------------------------------------------------------------------
EGAGLYPH    PROC NEAR
        push    bp
        mov     bp,sp
        push    ss
        push    ds
        mov     ax,0A000h
        mov     es,ax
        mov     ax,[bp+0Ah]             ; row
        mov     bx,140h                 ; 320 = 8 scanlines x 40 bytes
        mul     bx
        add     ax,[bp+0Ch]             ; + col
        mov     di,ax
        mov     dx,3CEh
        mov     ax,0A05h                ; GC 5 (Mode) := 0Ah  write-mode 2, read-mode 1
        out     dx,ax
        mov     ah,0
        mov     al,3
        out     dx,ax                   ; GC 3 (Data Rotate) := 0
        mov     ax,7                    ; GC 7 (Color Don't Care) := 0
        out     dx,ax
        xor     bx,bx                   ; glyph row index
        mov     cx,8
EGA_ROW:
        mov     ah,[bx+GLYPHROWBUF]
        mov     al,8
        out     dx,ax                   ; GC 8 (Bit Mask) := glyph row
        mov     al,[bp+8]               ; fg
        and     es:[di],al              ; read-modify-write
        not     ah
        mov     al,8
        out     dx,ax                   ; GC 8 := complement
        mov     al,[bp+6]               ; bg
        and     es:[di],al
        add     di,28h                  ; next scanline
        inc     bx
        loop    EGA_ROW
        mov     ax,5                    ; GC 5 := 0  (write mode 0)
        out     dx,ax
        mov     ax,0FF08h               ; GC 8 := FFh
        out     dx,ax
        mov     ax,3                    ; GC 3 := 0
        out     dx,ax
        mov     ax,0F07h                ; GC 7 := 0Fh
        out     dx,ax
        pop     ds
        pop     ss
        pop     bp
        ret     0Ah
EGAGLYPH    ENDP

; ---------------------------------------------------------------------------
; TANDYGLYPH -- Tandy, four interleaved banks at 4 bits per pixel, so a cell is 4 bytes wide and col is scaled by
; 4.  fg and bg are held in dh and dl as nibble pairs and rotated a nibble per pixel.  Each pass of the outer loop
; paints one glyph row into each of the four banks, and two passes paint all eight.  Each cell is written from its
; last byte down.
; ---------------------------------------------------------------------------
TANDYGLYPH  PROC NEAR
        push    bp
        mov     bp,sp
        push    ss
        push    ds
        mov     ax,[bp+0Ah]             ; row
        mov     bx,140h
        mul     bx
        mov     bx,[bp+0Ch]             ; col
        shl     bx,1                    ; col * 4
        shl     bx,1
        add     ax,bx
        mov     di,ax
        mov     dl,[bp+6]               ; bg
        mov     dh,[bp+8]               ; fg
        xor     bx,bx                   ; glyph row index
        mov     ah,1                    ; walking bit, LSB-first within the row byte
        mov     cx,2
TDY_PASS:
        push    cx
        ; --- bank 0 ---
        mov     cx,0B800h
        mov     es,cx
        mov     cx,4
        add     di,3
TDY_B0_COL:
        push    cx
        mov     cx,2
        mov     al,0
TDY_B0_PIX:
        test    byte ptr [bx+GLYPHROWBUF],ah
        je      TDY_B0_BG
        or      al,dh                   ; fg
        jmp     short TDY_B0_NEXT
        nop
TDY_B0_BG:
        or      al,dl                   ; bg
TDY_B0_NEXT:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    TDY_B0_PIX
        mov     es:[di],al
        dec     di
        pop     cx
        loop    TDY_B0_COL
        add     di,4
        inc     bx
        ; --- bank 1 ---
        mov     cx,0BA00h
        mov     es,cx
        mov     cx,4
TDY_B1_COL:
        push    cx
        mov     cx,2
        mov     al,0
TDY_B1_PIX:
        test    byte ptr [bx+GLYPHROWBUF],ah
        je      TDY_B1_BG
        or      al,dh
        jmp     short TDY_B1_NEXT
        nop
TDY_B1_BG:
        or      al,dl
TDY_B1_NEXT:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    TDY_B1_PIX
        mov     es:[di],al
        dec     di
        pop     cx
        loop    TDY_B1_COL
        add     di,4
        inc     bx
        ; --- bank 2 ---
        mov     cx,0BC00h
        mov     es,cx
        mov     cx,4
TDY_B2_COL:
        push    cx
        mov     cx,2
        mov     al,0
TDY_B2_PIX:
        test    byte ptr [bx+GLYPHROWBUF],ah
        je      TDY_B2_BG
        or      al,dh
        jmp     short TDY_B2_NEXT
        nop
TDY_B2_BG:
        or      al,dl
TDY_B2_NEXT:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    TDY_B2_PIX
        mov     es:[di],al
        dec     di
        pop     cx
        loop    TDY_B2_COL
        add     di,4
        inc     bx
        ; --- bank 3 ---
        mov     cx,0BE00h
        mov     es,cx
        mov     cx,4
TDY_B3_COL:
        push    cx
        mov     cx,2
        mov     al,0
TDY_B3_PIX:
        test    byte ptr [bx+GLYPHROWBUF],ah
        je      TDY_B3_BG
        or      al,dh
        jmp     short TDY_B3_NEXT
        nop
TDY_B3_BG:
        or      al,dl
TDY_B3_NEXT:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    TDY_B3_PIX
        mov     es:[di],al
        dec     di
        pop     cx
        loop    TDY_B3_COL
        inc     bx
        add     di,0A1h                 ; the next scanline of each bank
        pop     cx
        dec     cx                      ; `loop TDY_PASS` is out of short range, so the
        je      TDY_DONE                ;   pass counter is decremented by hand
        jmp     TDY_PASS
TDY_DONE:
        pop     ds
        pop     ss
        pop     bp
        ret     0Ah
TANDYGLYPH  ENDP

; ---------------------------------------------------------------------------
; VGAGLYPH -- MCGA, one byte per pixel, so the cell origin is (row * 320 + col) * 8 and the step to the next
; scanline is 320 - 8 bytes.  It reads glyph `glyph` from the font through gameFont.
; ---------------------------------------------------------------------------
VGAGLYPH   PROC FAR
        push    bp
        mov     bp,sp
        cld
        push    ds
        lds     si,GAMEFONT
        xor     ax,ax
        mov     al,[bp+6]               ; glyph
        mov     bx,8
        mul     bx
        add     si,ax                   ; si = gameFont + glyph * 8
        mov     bx,140h
        mov     ax,[bp+0Ch]             ; row
        mul     bx
        add     ax,[bp+0Eh]             ; + col
        mov     bx,8
        mul     bx                      ; x8 -- one byte per pixel
        mov     di,ax
        mov     ax,0A000h
        mov     es,ax
        mov     cx,8                    ; 8 glyph rows
        xor     ax,ax
MCGA_ROW:
        push    cx
        mov     cx,8                    ; 8 pixels
        mov     bx,80h                  ; walking bit, MSB-first
MCGA_PIX:
        mov     al,[si]
        and     ax,bx
        cmp     ax,0
        jne     MCGA_FG
        mov     al,[bp+8]               ; bg
        stosb
        jmp     short MCGA_NEXT
        nop
MCGA_FG:
        mov     al,[bp+0Ah]             ; fg
        stosb
MCGA_NEXT:
        shr     bx,1
        loop    MCGA_PIX
        pop     cx
        inc     si
        add     di,138h                 ; 320 - 8
        loop    MCGA_ROW
        pop     ds
        pop     bp
        ret     0Ah
VGAGLYPH   ENDP

CODE    ENDS
        END
