; The assembler half of the Blit unit, linked into its code segment through {$L BLIT.OBJ}: the tile blitters
; BlitTileCell and BlitTileClipped dispatch to, one set per display class, and the DAC loader SetDacPalette calls.
;
; Every entry point is near and ends in `ret n`, popping its own arguments.
; Each prologue reserves the frame twice; the locals use the first, and `mov sp,bp` drops both.
;
; Entries, with display class, kind and row loop: BLITCELLEGA (EGA, plain, INNER0); BLITCELLEGAMASKED (EGA, masked,
; INNER1); BLITCLIPPEDEGA (EGA, clipped, INNER0 or INNER1); BLITCELLTANDY (Tandy, plain, INNER0); BLITCELLTANDYMASKED
; (Tandy, masked, INNER1); BLITCLIPPEDTANDY (Tandy, clipped, INNER0 or INNER1); BLITCELLVGA (MCGA, plain, INNER2);
; BLITCELLVGAKEYED (MCGA, color-keyed, INNER3); BLITCLIPPEDVGA (MCGA, clipped, INNER2 or INNER3).
; PROGRAMPALETTEONRETRACE loads the VGA DAC block.
;
; The row loops have no frame of their own: they run inside the calling blitter's frame and return with a bare `ret`.
; INNER0 and INNER1 follow BLITCLIPPEDTANDY's code, INNER2 and INNER3 follow BLITCLIPPEDVGA's.
;
; EGA and Tandy store 4 bytes per 8-pixel cell and MCGA 8, so the EGA and Tandy blitters scale by two shifts and the
; MCGA blitters by three.
;
; The row loops record what they draw in the four span tables, which FlushView copies to the screen.  Each loop marks
; its row in spanRowActive, lowers the row's spanFirstOfs (setting spanScreenOfs with it) and raises its spanLastOfs.
; bx carries the row as a slot number for spanRowActive and is doubled for the three Word tables, then halved again at
; the bottom of the loop.  The tables are reached through DS, which holds the data segment whenever a loop touches them.

DGROUP  GROUP   DATA
DATA    SEGMENT WORD PUBLIC
        EXTRN   SPANROWACTIVE:BYTE
        EXTRN   SPANSCREENOFS:WORD
        EXTRN   SPANFIRSTOFS:WORD
        EXTRN   SPANLASTOFS:WORD
DATA    ENDS

CODE    SEGMENT BYTE PUBLIC
        ASSUME  CS:CODE, DS:DGROUP
        PUBLIC  BLITCELLEGA
        PUBLIC  BLITCELLEGAMASKED
        PUBLIC  BLITCLIPPEDEGA
        PUBLIC  BLITCELLTANDY
        PUBLIC  BLITCELLTANDYMASKED
        PUBLIC  BLITCLIPPEDTANDY
        PUBLIC  BLITCELLVGA
        PUBLIC  BLITCELLVGAKEYED
        PUBLIC  BLITCLIPPEDVGA
        PUBLIC  PROGRAMPALETTEONRETRACE


; --------------------------------------------------------------------------
; BLITCELLEGA -- EGA, plain: draws frame tileIdx of gfx into dest at cell (screenX, screenY).
; --------------------------------------------------------------------------
BLITCELLEGA:
        push    bp
        mov     bp,sp
        sub     sp,1Ch
        sub     sp,1Ch
        push    ss
        push    ds
        cld
        les     di,dword ptr [bp+4h]
        mov     ax,[bp+0Eh]
        mov     cl,3h
        shl     ax,cl
        mov     [bp-8h],ax
        mov     bx,es:[di+2h]
        mul     bx
        mov     [bp-0Ch],ax
        mov     ax,[bp+10h]
        mov     [bp-14h],ax
        mov     ax,es:[di+2h]
        les     di,dword ptr [bp+8h]
        sub     ax,es:[di+2h]
        sub     ax,[bp+10h]
        mov     [bp-12h],ax
        mov     ax,[bp-14h]
        mov     [bp-6h],ax
        mov     ax,es:[di+2h]
        shl     ax,1h
        shl     ax,1h
        mov     [bp-10h],ax
        mov     ax,es:[di]
        mov     [bp-0Ah],ax
        shl     word ptr [bp-14h],1h
        shl     word ptr [bp-14h],1h
        shl     word ptr [bp-12h],1h
        shl     word ptr [bp-12h],1h
        mov     ax,es:[di+12h]
        xor     bx,bx
        mov     bl,[bp+0Ch]
        mul     bx
        mov     [bp-0Eh],ax
        shl     word ptr [bp-0Ch],1h
        shl     word ptr [bp-0Ch],1h
        mov     bx,[bp-8h]
        mov     cx,[bp-0Ah]
        mov     byte ptr [bp-1Ah],0h
        mov     word ptr [bp-18h],0h
        mov     word ptr [bp-16h],0h
        call    INNER0
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh

; --------------------------------------------------------------------------
; BLITCELLEGAMASKED -- EGA, masked: BLITCELLEGA through the image's mask.
; --------------------------------------------------------------------------
BLITCELLEGAMASKED:
        push    bp
        mov     bp,sp
        sub     sp,1Ch
        sub     sp,1Ch
        push    ss
        push    ds
        cld
        les     di,dword ptr [bp+4h]
        mov     ax,[bp+0Eh]
        mov     cl,3h
        shl     ax,cl
        mov     [bp-8h],ax
        mov     bx,es:[di+2h]
        mul     bx
        mov     [bp-0Ch],ax
        mov     ax,[bp+10h]
        mov     [bp-14h],ax
        mov     ax,es:[di+2h]
        les     di,dword ptr [bp+8h]
        sub     ax,es:[di+2h]
        sub     ax,[bp+10h]
        mov     [bp-12h],ax
        mov     ax,[bp-14h]
        mov     [bp-6h],ax
        mov     ax,es:[di+2h]
        shl     ax,1h
        shl     ax,1h
        mov     [bp-10h],ax
        mov     ax,es:[di]
        mov     [bp-0Ah],ax
        mov     ax,es:[di+17h]
        mov     [bp-4h],ax
        mov     ax,es:[di+19h]
        mov     [bp-2h],ax
        shl     word ptr [bp-14h],1h
        shl     word ptr [bp-14h],1h
        shl     word ptr [bp-12h],1h
        shl     word ptr [bp-12h],1h
        mov     ax,es:[di+12h]
        xor     bx,bx
        mov     bl,[bp+0Ch]
        mul     bx
        mov     [bp-0Eh],ax
        shl     word ptr [bp-0Ch],1h
        shl     word ptr [bp-0Ch],1h
        mov     bx,[bp-8h]
        mov     cx,[bp-0Ah]
        mov     byte ptr [bp-1Ah],0h
        mov     word ptr [bp-18h],0h
        mov     word ptr [bp-16h],0h
        call    INNER1
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh

; --------------------------------------------------------------------------
; BLITCLIPPEDEGA -- EGA, clipped: clips the frame against dest and returns at once when nothing is left.  Bit 0 of flag
; picks INNER1, the masked loop, over INNER0, and bit 2 has INNER1 first save the covered pixels into iconSaveBuf.
; --------------------------------------------------------------------------
BLITCLIPPEDEGA:
        push    bp
        mov     bp,sp
        sub     sp,1Ch
        sub     sp,1Ch
        push    ss
        push    ds
        cld
        push    ds
        lds     si,dword ptr [bp+8h]
        les     di,dword ptr [bp+4h]
        mov     ax,[si+17h]
        mov     [bp-4h],ax
        mov     ax,[si+19h]
        mov     [bp-2h],ax
        mov     ax,[bp+12h]
        cmp     ax,8000h
        jbe     L22D1
        mov     [bp-18h],ax
        neg     word ptr [bp-18h]
        mov     word ptr [bp-14h],0h
        jmp     short L22D9
        nop
L22D1:
        mov     word ptr [bp-18h],0h
        mov     [bp-14h],ax
L22D9:
        add     ax,[si+2h]
        cmp     es:[di+2h],ax
        jae     L22F1
        sub     ax,es:[di+2h]
        mov     [bp-16h],ax
        mov     word ptr [bp-12h],0h
        jmp     short L2303
        nop
L22F1:
        mov     word ptr [bp-16h],0h
        mov     ax,es:[di+2h]
        sub     ax,[bp+12h]
        sub     ax,[si+2h]
        mov     [bp-12h],ax
L2303:
        mov     ax,[bp+10h]
        cmp     ax,8000h
        jbe     L232F
        neg     ax
        mov     cx,3h
        shl     ax,cl
        mov     bx,[si]
        mov     [bp-0Ah],bx
        sub     [bp-0Ah],ax
        mov     bx,[si+2h]
        mul     bx
        mov     [bp-0Eh],ax
        mov     word ptr [bp-0Ch],0h
        mov     word ptr [bp-8h],0h
        jmp     short L2360
        nop
L232F:
        mov     word ptr [bp-0Eh],0h
        mov     cx,3h
        shl     ax,cl
        mov     [bp-8h],ax
        mov     bx,es:[di+2h]
        mul     bx
        mov     [bp-0Ch],ax
        mov     ax,[bp-8h]
        add     ax,[si]
        cmp     ax,es:[di]
        jbe     L235B
        mov     ax,es:[di]
        sub     ax,[bp-8h]
        mov     [bp-0Ah],ax
        jmp     short L2360
        nop
L235B:
        mov     ax,[si]
        mov     [bp-0Ah],ax
L2360:
        mov     ax,[si+2h]
        cmp     ax,[bp-18h]
        jb      L2388
        cmp     ax,[bp-16h]
        jb      L2388
        mov     ax,[bp-0Eh]
        cmp     ax,[si+12h]
        ja      L2388
        mov     ax,[bp-0Ch]
        cmp     ax,es:[di+12h]
        ja      L2388
        mov     ax,[bp-0Ah]
        cmp     ax,[si]
        ja      L2388
        jmp     short L2391
        nop
L2388:
        pop     ds
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
L2391:
        mov     ax,[bp-14h]
        mov     [bp-6h],ax
        mov     ax,[bp-14h]
        shl     ax,1h
        shl     ax,1h
        mov     [bp-14h],ax
        mov     ax,[si+2h]
        sub     ax,[bp-18h]
        sub     ax,[bp-16h]
        shl     ax,1h
        shl     ax,1h
        mov     [bp-10h],ax
        shl     word ptr [bp-18h],1h
        shl     word ptr [bp-18h],1h
        shl     word ptr [bp-16h],1h
        shl     word ptr [bp-16h],1h
        shl     word ptr [bp-12h],1h
        shl     word ptr [bp-12h],1h
        shl     word ptr [bp-0Eh],1h
        shl     word ptr [bp-0Eh],1h
        shl     word ptr [bp-0Ch],1h
        shl     word ptr [bp-0Ch],1h
        mov     ax,[bp-0Eh]
        mov     [bp-1Ch],ax
        mov     ax,[si+12h]
        xor     bx,bx
        mov     bl,[bp+0Eh]
        mul     bx
        add     [bp-0Eh],ax
        mov     bx,[bp-8h]
        mov     cx,[bp-0Ah]
        mov     byte ptr [bp-1Ah],0h
        pop     ds
        test    byte ptr [bp+0Ch],1h
        jne     L23FE
        call    INNER0
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
L23FE:
        mov     byte ptr [bp-1Ah],0h
        test    byte ptr [bp+0Ch],4h
        je      L240C
        mov     byte ptr [bp-1Ah],1h
L240C:
        call    INNER1
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h

; --------------------------------------------------------------------------
; BLITCELLTANDY -- Tandy, plain.
; --------------------------------------------------------------------------
BLITCELLTANDY:
        push    bp
        mov     bp,sp
        sub     sp,1Ch
        sub     sp,1Ch
        push    ss
        push    ds
        cld
        les     di,dword ptr [bp+4h]
        mov     ax,[bp+0Eh]
        mov     cl,3h
        shl     ax,cl
        mov     [bp-8h],ax
        mov     bx,es:[di+2h]
        mul     bx
        mov     [bp-0Ch],ax
        mov     ax,[bp+10h]
        mov     [bp-14h],ax
        mov     ax,es:[di+2h]
        les     di,dword ptr [bp+8h]
        sub     ax,es:[di+2h]
        sub     ax,[bp+10h]
        mov     [bp-12h],ax
        mov     ax,[bp-14h]
        mov     [bp-6h],ax
        shl     word ptr [bp-6h],1h
        shl     word ptr [bp-6h],1h
        mov     ax,es:[di+2h]
        shl     ax,1h
        shl     ax,1h
        mov     [bp-10h],ax
        mov     ax,es:[di]
        mov     [bp-0Ah],ax
        shl     word ptr [bp-14h],1h
        shl     word ptr [bp-14h],1h
        shl     word ptr [bp-12h],1h
        shl     word ptr [bp-12h],1h
        mov     ax,es:[di+12h]
        xor     bx,bx
        mov     bl,[bp+0Ch]
        mul     bx
        mov     [bp-0Eh],ax
        shl     word ptr [bp-0Ch],1h
        shl     word ptr [bp-0Ch],1h
        mov     bx,[bp-8h]
        mov     cx,[bp-0Ah]
        mov     byte ptr [bp-1Ah],0h
        mov     word ptr [bp-18h],0h
        mov     word ptr [bp-16h],0h
        call    INNER0
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh

; --------------------------------------------------------------------------
; BLITCELLTANDYMASKED -- Tandy, masked.
; --------------------------------------------------------------------------
BLITCELLTANDYMASKED:
        push    bp
        mov     bp,sp
        sub     sp,1Ch
        sub     sp,1Ch
        push    ss
        push    ds
        les     di,dword ptr [bp+4h]
        mov     ax,[bp+0Eh]
        mov     cl,3h
        shl     ax,cl
        mov     [bp-8h],ax
        mov     bx,es:[di+2h]
        mul     bx
        mov     [bp-0Ch],ax
        mov     ax,[bp+10h]
        mov     [bp-14h],ax
        mov     ax,es:[di+2h]
        les     di,dword ptr [bp+8h]
        sub     ax,es:[di+2h]
        sub     ax,[bp+10h]
        mov     [bp-12h],ax
        mov     ax,[bp-14h]
        mov     [bp-6h],ax
        shl     word ptr [bp-6h],1h
        shl     word ptr [bp-6h],1h
        mov     ax,es:[di+2h]
        shl     ax,1h
        shl     ax,1h
        mov     [bp-10h],ax
        mov     ax,es:[di]
        mov     [bp-0Ah],ax
        mov     ax,es:[di+17h]
        mov     [bp-4h],ax
        mov     ax,es:[di+19h]
        mov     [bp-2h],ax
        shl     word ptr [bp-14h],1h
        shl     word ptr [bp-14h],1h
        shl     word ptr [bp-12h],1h
        shl     word ptr [bp-12h],1h
        mov     ax,es:[di+12h]
        xor     bx,bx
        mov     bl,[bp+0Ch]
        mul     bx
        mov     [bp-0Eh],ax
        shl     word ptr [bp-0Ch],1h
        shl     word ptr [bp-0Ch],1h
        mov     bx,[bp-8h]
        mov     cx,[bp-0Ah]
        mov     byte ptr [bp-1Ah],0h
        mov     word ptr [bp-18h],0h
        mov     word ptr [bp-16h],0h
        call    INNER1
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh

; --------------------------------------------------------------------------
; BLITCLIPPEDTANDY -- Tandy, clipped, as BLITCLIPPEDEGA.
; --------------------------------------------------------------------------
BLITCLIPPEDTANDY:
        push    bp
        mov     bp,sp
        sub     sp,1Ch
        sub     sp,1Ch
        push    ss
        push    ds
        cld
        push    ds
        lds     si,dword ptr [bp+8h]
        les     di,dword ptr [bp+4h]
        mov     ax,[si+17h]
        mov     [bp-4h],ax
        mov     ax,[si+19h]
        mov     [bp-2h],ax
        mov     ax,[bp+12h]
        cmp     ax,8000h
        jbe     L2583
        mov     [bp-18h],ax
        neg     word ptr [bp-18h]
        mov     word ptr [bp-14h],0h
        jmp     short L258B
        nop
L2583:
        mov     word ptr [bp-18h],0h
        mov     [bp-14h],ax
L258B:
        add     ax,[si+2h]
        cmp     es:[di+2h],ax
        jae     L25A3
        sub     ax,es:[di+2h]
        mov     [bp-16h],ax
        mov     word ptr [bp-12h],0h
        jmp     short L25B5
        nop
L25A3:
        mov     word ptr [bp-16h],0h
        mov     ax,es:[di+2h]
        sub     ax,[bp+12h]
        sub     ax,[si+2h]
        mov     [bp-12h],ax
L25B5:
        mov     ax,[bp+10h]
        cmp     ax,8000h
        jbe     L25E1
        neg     ax
        mov     cx,3h
        shl     ax,cl
        mov     bx,[si]
        mov     [bp-0Ah],bx
        sub     [bp-0Ah],ax
        mov     bx,[si+2h]
        mul     bx
        mov     [bp-0Eh],ax
        mov     word ptr [bp-0Ch],0h
        mov     word ptr [bp-8h],0h
        jmp     short L2612
        nop
L25E1:
        mov     word ptr [bp-0Eh],0h
        mov     cx,3h
        shl     ax,cl
        mov     [bp-8h],ax
        mov     bx,es:[di+2h]
        mul     bx
        mov     [bp-0Ch],ax
        mov     ax,[bp-8h]
        add     ax,[si]
        cmp     ax,es:[di]
        jbe     L260D
        mov     ax,es:[di]
        sub     ax,[bp-8h]
        mov     [bp-0Ah],ax
        jmp     short L2612
        nop
L260D:
        mov     ax,[si]
        mov     [bp-0Ah],ax
L2612:
        mov     ax,[si+2h]
        cmp     ax,[bp-18h]
        jb      L263A
        cmp     ax,[bp-16h]
        jb      L263A
        mov     ax,[bp-0Eh]
        cmp     ax,[si+12h]
        ja      L263A
        mov     ax,[bp-0Ch]
        cmp     ax,es:[di+12h]
        ja      L263A
        mov     ax,[bp-0Ah]
        cmp     ax,[si]
        ja      L263A
        jmp     short L2643
        nop
L263A:
        pop     ds
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
L2643:
        mov     ax,[bp-14h]
        shl     ax,1h
        shl     ax,1h
        mov     [bp-14h],ax
        mov     [bp-6h],ax
        mov     ax,[si+2h]
        sub     ax,[bp-18h]
        sub     ax,[bp-16h]
        shl     ax,1h
        shl     ax,1h
        mov     [bp-10h],ax
        shl     word ptr [bp-18h],1h
        shl     word ptr [bp-18h],1h
        shl     word ptr [bp-16h],1h
        shl     word ptr [bp-16h],1h
        shl     word ptr [bp-12h],1h
        shl     word ptr [bp-12h],1h
        shl     word ptr [bp-0Eh],1h
        shl     word ptr [bp-0Eh],1h
        shl     word ptr [bp-0Ch],1h
        shl     word ptr [bp-0Ch],1h
        mov     ax,[bp-0Eh]
        mov     [bp-1Ch],ax
        mov     ax,[si+12h]
        xor     bx,bx
        mov     bl,[bp+0Eh]
        mul     bx
        add     [bp-0Eh],ax
        mov     bx,[bp-8h]
        mov     cx,[bp-0Ah]
        mov     byte ptr [bp-1Ah],0h
        pop     ds
        test    byte ptr [bp+0Ch],1h
        jne     L26AD
        call    INNER0
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
L26AD:
        mov     byte ptr [bp-1Ah],0h
        test    byte ptr [bp+0Ch],4h
        je      L26BB
        mov     byte ptr [bp-1Ah],1h
L26BB:
        call    INNER1
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h

; --------------------------------------------------------------------------
; INNER0 -- the plain row loop at 4 bytes per cell: copies each row's run with `rep movsb`.
; --------------------------------------------------------------------------
INNER0:
        mov     byte ptr SPANROWACTIVE[bx],1h
        shl     bx,1h
        mov     ax,[bp-14h]
        add     [bp-0Ch],ax
        mov     ax,[bp-0Ch]
        cmp     ax,SPANFIRSTOFS[bx]
        ja      L26E7
        mov     SPANFIRSTOFS[bx],ax
        mov     ax,[bp-6h]
        mov     SPANSCREENOFS[bx],ax
L26E7:
        push    ds
        lds     si,dword ptr [bp+8h]
        les     di,dword ptr [bp+4h]
        add     si,1Bh
        add     si,[bp-0Eh]
        add     di,1Bh
        add     di,[bp-0Ch]
        push    cx
        mov     cx,[bp-10h]
        rep movsb
        pop     cx
        pop     ds
        mov     ax,[bp-10h]
        add     [bp-0Eh],ax
        add     [bp-0Ch],ax
        mov     ax,[bp-0Ch]
        dec     ax
        cmp     ax,SPANLASTOFS[bx]
        jb      L2719
        mov     SPANLASTOFS[bx],ax
L2719:
        mov     ax,[bp-12h]
        add     [bp-0Ch],ax
        shr     bx,1h
        inc     bx
        loop    INNER0
        ret

; --------------------------------------------------------------------------
; INNER1 -- the masked row loop at 4 bytes per cell, a byte at a time: saves the covered byte into iconSaveBuf when
; asked, then ANDs the mask byte in and ORs the source byte over it.  It ends in `dec cx / je / jmp`, the loop being
; too long for `loop`.
; --------------------------------------------------------------------------
INNER1:
        mov     byte ptr SPANROWACTIVE[bx],1h
        shl     bx,1h
        mov     ax,[bp-18h]
        add     [bp-0Eh],ax
        mov     ax,[bp-14h]
        add     [bp-0Ch],ax
        mov     ax,[bp-0Ch]
        cmp     ax,SPANFIRSTOFS[bx]
        jae     L274C
        mov     SPANFIRSTOFS[bx],ax
        mov     ax,[bp-6h]
        mov     SPANSCREENOFS[bx],ax
L274C:
        push    ds
        les     di,dword ptr [bp+4h]
        add     di,[bp-0Ch]
        push    cx
        mov     cx,[bp-10h]
L2757:
        cmp     byte ptr [bp-1Ah],0h
        je      L276A
        lds     si,dword ptr [bp+14h]
        add     si,[bp-1Ch]
        mov     al,es:[di+1Bh]
        mov     [si+1Bh],al
L276A:
        lds     si,dword ptr [bp-4h]
        add     si,[bp-0Eh]
        mov     ah,[si]
        lds     si,dword ptr [bp+8h]
        add     si,[bp-0Eh]
        mov     al,[si+1Bh]
        and     es:[di+1Bh],ah
        or      es:[di+1Bh],al
        inc     word ptr [bp-0Eh]
        inc     word ptr [bp-1Ch]
        inc     word ptr [bp-0Ch]
        inc     di
        loop    L2757
        pop     cx
        pop     ds
        mov     ax,[bp-0Ch]
        dec     ax
        cmp     ax,SPANLASTOFS[bx]
        jbe     L279F
        mov     SPANLASTOFS[bx],ax
L279F:
        mov     ax,[bp-12h]
        add     [bp-0Ch],ax
        mov     ax,[bp-16h]
        add     [bp-0Eh],ax
        add     [bp-1Ch],ax
        shr     bx,1h
        inc     bx
        dec     cx
        je      L27B7
        jmp     INNER1
L27B7:
        ret

; --------------------------------------------------------------------------
; BLITCELLVGA -- MCGA, plain.
; --------------------------------------------------------------------------
BLITCELLVGA:
        push    bp
        mov     bp,sp
        sub     sp,1Ch
        sub     sp,1Ch
        push    ss
        push    ds
        cld
        les     di,dword ptr [bp+4h]
        mov     ax,[bp+0Eh]
        mov     cl,3h
        shl     ax,cl
        mov     [bp-8h],ax
        mov     bx,es:[di+2h]
        mul     bx
        mov     [bp-0Ch],ax
        mov     ax,[bp+10h]
        mov     [bp-14h],ax
        mov     ax,es:[di+2h]
        les     di,dword ptr [bp+8h]
        sub     ax,es:[di+2h]
        sub     ax,[bp+10h]
        mov     [bp-12h],ax
        mov     ax,[bp-14h]
        mov     [bp-6h],ax
        shl     word ptr [bp-6h],1h
        shl     word ptr [bp-6h],1h
        shl     word ptr [bp-6h],1h
        mov     ax,es:[di+2h]
        shl     ax,1h
        shl     ax,1h
        shl     ax,1h
        mov     [bp-10h],ax
        mov     ax,es:[di]
        mov     [bp-0Ah],ax
        shl     word ptr [bp-14h],1h
        shl     word ptr [bp-14h],1h
        shl     word ptr [bp-14h],1h
        shl     word ptr [bp-12h],1h
        shl     word ptr [bp-12h],1h
        shl     word ptr [bp-12h],1h
        mov     ax,es:[di+12h]
        xor     bx,bx
        mov     bl,[bp+0Ch]
        mul     bx
        mov     [bp-0Eh],ax
        shl     word ptr [bp-0Ch],1h
        shl     word ptr [bp-0Ch],1h
        shl     word ptr [bp-0Ch],1h
        mov     bx,[bp-8h]
        mov     cx,[bp-0Ah]
        mov     byte ptr [bp-1Ah],0h
        mov     word ptr [bp-18h],0h
        mov     word ptr [bp-16h],0h
        call    INNER2
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh

; --------------------------------------------------------------------------
; BLITCELLVGAKEYED -- MCGA, color-keyed: takes the key color as one more argument and keeps it in the frame for
; INNER3.
; --------------------------------------------------------------------------
BLITCELLVGAKEYED:
        push    bp
        mov     bp,sp
        sub     sp,1Eh
        sub     sp,1Eh
        push    ss
        push    ds
        les     di,dword ptr [bp+4h]
        mov     ah,[bp+0Eh]
        mov     [bp-1Ch],ah
        mov     ax,[bp+10h]
        mov     cl,3h
        shl     ax,cl
        mov     [bp-8h],ax
        mov     bx,es:[di+2h]
        mul     bx
        mov     [bp-0Ch],ax
        mov     ax,[bp+12h]
        mov     [bp-14h],ax
        mov     ax,es:[di+2h]
        les     di,dword ptr [bp+8h]
        sub     ax,es:[di+2h]
        sub     ax,[bp+12h]
        mov     [bp-12h],ax
        mov     ax,[bp-14h]
        mov     [bp-6h],ax
        shl     word ptr [bp-6h],1h
        shl     word ptr [bp-6h],1h
        shl     word ptr [bp-6h],1h
        mov     ax,es:[di+2h]
        shl     ax,1h
        shl     ax,1h
        shl     ax,1h
        mov     [bp-10h],ax
        mov     ax,es:[di]
        mov     [bp-0Ah],ax
        mov     ax,es:[di+17h]
        mov     [bp-4h],ax
        mov     ax,es:[di+19h]
        mov     [bp-2h],ax
        shl     word ptr [bp-14h],1h
        shl     word ptr [bp-14h],1h
        shl     word ptr [bp-14h],1h
        shl     word ptr [bp-12h],1h
        shl     word ptr [bp-12h],1h
        shl     word ptr [bp-12h],1h
        mov     ax,es:[di+12h]
        xor     bx,bx
        mov     bl,[bp+0Ch]
        mul     bx
        mov     [bp-0Eh],ax
        shl     word ptr [bp-0Ch],1h
        shl     word ptr [bp-0Ch],1h
        shl     word ptr [bp-0Ch],1h
        mov     bx,[bp-8h]
        mov     cx,[bp-0Ah]
        mov     byte ptr [bp-1Ah],0h
        mov     word ptr [bp-18h],0h
        mov     word ptr [bp-16h],0h
        call    INNER3
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     10h

; --------------------------------------------------------------------------
; BLITCLIPPEDVGA -- MCGA, clipped, as BLITCLIPPEDEGA, with the key color as one more argument; bit 0 of flag picks
; INNER3.
; --------------------------------------------------------------------------
BLITCLIPPEDVGA:
        push    bp
        mov     bp,sp
        sub     sp,1Eh
        sub     sp,1Eh
        push    ss
        push    ds
        cld
        push    ds
        lds     si,dword ptr [bp+8h]
        les     di,dword ptr [bp+4h]
        mov     ax,[si+17h]
        mov     [bp-4h],ax
        mov     ax,[si+19h]
        mov     [bp-2h],ax
        mov     ah,[bp+10h]
        mov     [bp-1Ch],ah
        mov     ax,[bp+14h]
        cmp     ax,8000h
        jbe     L294C
        mov     [bp-18h],ax
        neg     word ptr [bp-18h]
        mov     word ptr [bp-14h],0h
        jmp     short L2954
        nop
L294C:
        mov     word ptr [bp-18h],0h
        mov     [bp-14h],ax
L2954:
        add     ax,[si+2h]
        cmp     es:[di+2h],ax
        jae     L296C
        sub     ax,es:[di+2h]
        mov     [bp-16h],ax
        mov     word ptr [bp-12h],0h
        jmp     short L297E
        nop
L296C:
        mov     word ptr [bp-16h],0h
        mov     ax,es:[di+2h]
        sub     ax,[bp+14h]
        sub     ax,[si+2h]
        mov     [bp-12h],ax
L297E:
        mov     ax,[bp+12h]
        cmp     ax,8000h
        jbe     L29AA
        neg     ax
        mov     cx,3h
        shl     ax,cl
        mov     bx,[si]
        mov     [bp-0Ah],bx
        sub     [bp-0Ah],ax
        mov     bx,[si+2h]
        mul     bx
        mov     [bp-0Eh],ax
        mov     word ptr [bp-0Ch],0h
        mov     word ptr [bp-8h],0h
        jmp     short L29DB
        nop
L29AA:
        mov     word ptr [bp-0Eh],0h
        mov     cx,3h
        shl     ax,cl
        mov     [bp-8h],ax
        mov     bx,es:[di+2h]
        mul     bx
        mov     [bp-0Ch],ax
        mov     ax,[bp-8h]
        add     ax,[si]
        cmp     ax,es:[di]
        jbe     L29D6
        mov     ax,es:[di]
        sub     ax,[bp-8h]
        mov     [bp-0Ah],ax
        jmp     short L29DB
        nop
L29D6:
        mov     ax,[si]
        mov     [bp-0Ah],ax
L29DB:
        mov     ax,[si+2h]
        cmp     ax,[bp-18h]
        jb      L2A03
        cmp     ax,[bp-16h]
        jb      L2A03
        mov     ax,[bp-0Eh]
        cmp     ax,[si+12h]
        ja      L2A03
        mov     ax,[bp-0Ch]
        cmp     ax,es:[di+12h]
        ja      L2A03
        mov     ax,[bp-0Ah]
        cmp     ax,[si]
        ja      L2A03
        jmp     short L2A0C
        nop
L2A03:
        pop     ds
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     16h
L2A0C:
        mov     ax,[bp-14h]
        shl     ax,1h
        shl     ax,1h
        shl     ax,1h
        mov     [bp-14h],ax
        mov     [bp-6h],ax
        mov     ax,[si+2h]
        sub     ax,[bp-18h]
        sub     ax,[bp-16h]
        shl     ax,1h
        shl     ax,1h
        shl     ax,1h
        mov     [bp-10h],ax
        shl     word ptr [bp-18h],1h
        shl     word ptr [bp-18h],1h
        shl     word ptr [bp-18h],1h
        shl     word ptr [bp-16h],1h
        shl     word ptr [bp-16h],1h
        shl     word ptr [bp-16h],1h
        shl     word ptr [bp-12h],1h
        shl     word ptr [bp-12h],1h
        shl     word ptr [bp-12h],1h
        shl     word ptr [bp-0Eh],1h
        shl     word ptr [bp-0Eh],1h
        shl     word ptr [bp-0Eh],1h
        shl     word ptr [bp-0Ch],1h
        shl     word ptr [bp-0Ch],1h
        shl     word ptr [bp-0Ch],1h
        mov     ax,[bp-0Eh]
        mov     [bp-1Eh],ax
        mov     ax,[si+12h]
        xor     bx,bx
        mov     bl,[bp+0Eh]
        mul     bx
        add     [bp-0Eh],ax
        mov     bx,[bp-8h]
        mov     cx,[bp-0Ah]
        mov     byte ptr [bp-1Ah],0h
        pop     ds
        test    byte ptr [bp+0Ch],1h
        jne     L2A89
        call    INNER2
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     16h
L2A89:
        mov     byte ptr [bp-1Ah],0h
        test    byte ptr [bp+0Ch],4h
        je      L2A97
        mov     byte ptr [bp-1Ah],1h
L2A97:
        call    INNER3
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     16h

; --------------------------------------------------------------------------
; INNER2 -- the plain row loop at 8 bytes per cell, the same code as INNER0.
; --------------------------------------------------------------------------
INNER2:
        mov     byte ptr SPANROWACTIVE[bx],1h
        shl     bx,1h
        mov     ax,[bp-14h]
        add     [bp-0Ch],ax
        mov     ax,[bp-0Ch]
        cmp     ax,SPANFIRSTOFS[bx]
        ja      L2AC3
        mov     SPANFIRSTOFS[bx],ax
        mov     ax,[bp-6h]
        mov     SPANSCREENOFS[bx],ax
L2AC3:
        push    ds
        lds     si,dword ptr [bp+8h]
        les     di,dword ptr [bp+4h]
        add     si,1Bh
        add     si,[bp-0Eh]
        add     di,1Bh
        add     di,[bp-0Ch]
        push    cx
        mov     cx,[bp-10h]
        rep movsb
        pop     cx
        pop     ds
        mov     ax,[bp-10h]
        add     [bp-0Eh],ax
        add     [bp-0Ch],ax
        mov     ax,[bp-0Ch]
        dec     ax
        cmp     ax,SPANLASTOFS[bx]
        jb      L2AF5
        mov     SPANLASTOFS[bx],ax
L2AF5:
        mov     ax,[bp-12h]
        add     [bp-0Ch],ax
        shr     bx,1h
        inc     bx
        loop    INNER2
        ret

; --------------------------------------------------------------------------
; INNER3 -- the color-keyed row loop: saves the covered byte into iconSaveBuf when asked, then stores each source byte
; that differs from the key color, which is how MCGA draws transparently.
; --------------------------------------------------------------------------
INNER3:
        mov     byte ptr SPANROWACTIVE[bx],1h
        shl     bx,1h
        mov     ax,[bp-18h]
        add     [bp-0Eh],ax
        mov     ax,[bp-14h]
        add     [bp-0Ch],ax
        mov     ax,[bp-0Ch]
        cmp     ax,SPANFIRSTOFS[bx]
        jae     L2B28
        mov     SPANFIRSTOFS[bx],ax
        mov     ax,[bp-6h]
        mov     SPANSCREENOFS[bx],ax
L2B28:
        push    ds
        les     di,dword ptr [bp+4h]
        add     di,[bp-0Ch]
        push    cx
        mov     cx,[bp-10h]
L2B33:
        cmp     byte ptr [bp-1Ah],0h
        je      L2B46
        lds     si,dword ptr [bp+16h]
        add     si,[bp-1Eh]
        mov     al,es:[di+1Bh]
        mov     [si+1Bh],al
L2B46:
        lds     si,dword ptr [bp+8h]
        add     si,[bp-0Eh]
        mov     al,[si+1Bh]
        cmp     al,[bp-1Ch]
        je      L2B58
        mov     es:[di+1Bh],al
L2B58:
        inc     word ptr [bp-0Eh]
        inc     word ptr [bp-1Eh]
        inc     word ptr [bp-0Ch]
        inc     di
        loop    L2B33
        pop     cx
        pop     ds
        mov     ax,[bp-0Ch]
        dec     ax
        cmp     ax,SPANLASTOFS[bx]
        jbe     L2B74
        mov     SPANLASTOFS[bx],ax
L2B74:
        mov     ax,[bp-12h]
        add     [bp-0Ch],ax
        mov     ax,[bp-16h]
        add     [bp-0Eh],ax
        add     [bp-1Eh],ax
        shr     bx,1h
        inc     bx
        dec     cx
        je      L2B8C
        jmp     INNER3
L2B8C:
        ret

; --------------------------------------------------------------------------
; PROGRAMPALETTEONRETRACE -- waits for the start of vertical retrace, then, with interrupts off, writes `count` RGB
; triplets from dac into the DAC from entry `first` on.
; --------------------------------------------------------------------------
PROGRAMPALETTEONRETRACE:
        push    bp
        mov     bp,sp
        push    ss
        push    ds
        cli
        mov     dx,3DAh
L2B96:
        in      al,dx
        test    al,8h
        jne     L2B96
L2B9B:
        in      al,dx
        test    al,8h
        je      L2B9B
        mov     dx,3C8h
        mov     ax,[bp+6h]
        out     dx,al
        inc     dx
        mov     cx,[bp+4h]
        lds     si,dword ptr [bp+8h]
        cld
L2BAF:
        lodsb
        out     dx,al
        lodsb
        out     dx,al
        lodsb
        out     dx,al
        loop    L2BAF
        sti
        pop     ds
        pop     ss
        pop     bp
        ret     8h

CODE    ENDS
        END
