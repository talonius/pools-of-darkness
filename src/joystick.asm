; The PC game-port reader, linked into Joystick and Startup by {$L JOYSTICK.OBJ}.
;
; ReadJoystick(joy: Byte; var xRaw, yRaw: Word; var buttons: Byte): Boolean;
; FAR, retf 0Eh, Boolean result in AL.
CODE    SEGMENT BYTE PUBLIC
        ASSUME  CS:CODE
        PUBLIC  READJOYSTICK

JOY_FIRST       EQU     1
JOY_LAST        EQU     2
GAME_PORT       EQU     201h
GAME_PORT_STROBE EQU    0FFh
SETTLE_COUNT    EQU     1FFFh
BUTTON_SHIFT    EQU     4
ARG_BUTTONS     EQU     06h
ARG_Y_RAW       EQU     0Ah
ARG_X_RAW       EQU     0Eh
ARG_JOY         EQU     12h

READJOYSTICK    PROC FAR
        push    bp
        mov     bp,sp
        cmp     byte ptr [bp+ARG_JOY],JOY_FIRST
        jz      valid
        cmp     byte ptr [bp+ARG_JOY],JOY_LAST
        jz      valid
        mov     al,0                    ; bad joy# -> False
        pop     bp
        ret     0Eh
valid:
        mov     ah,1                    ; button/axis bit mask: bit 0 for joystick 1, bit 2 for joystick 2
        xor     bx,bx
        cmp     byte ptr [bp+ARG_JOY],JOY_LAST
        jnz     m_set
        shl     ah,1
        shl     ah,1
m_set:
        mov     bx,1
        xor     cx,cx
        mov     al,GAME_PORT_STROBE
        mov     dx,GAME_PORT
        out     dx,al                   ; start capacitor discharge
xLoop:
        in      al,dx
        not     al
        test    al,ah
        jnz     xDone
        inc     bx
        loop    xLoop
        mov     al,0                    ; X axis timed out -> False
        pop     bp
        ret     0Eh
xDone:
        mov     cx,SETTLE_COUNT         ; delay proportional to leftover count
        sub     cx,bx
        jc      xStore
        loop    $
xStore:
        les     di,[bp+ARG_X_RAW]
        mov     es:[di],bx              ; xRaw := count
        shl     ah,1                    ; advance mask to Y axis
        xor     cx,cx
yLoop:
        in      al,dx
        not     al
        test    al,ah
        jnz     yPre
        loop    yLoop
        mov     al,0
        pop     bp
        ret     0Eh
yPre:
        mov     bx,1
        xor     cx,cx
        mov     al,GAME_PORT_STROBE
        out     dx,al
yLoop2:
        in      al,dx
        not     al
        test    al,ah
        jnz     yDone
        inc     bx
        loop    yLoop2
        mov     al,0
        pop     bp
        ret     0Eh
yDone:
        mov     cx,SETTLE_COUNT
        sub     cx,bx
        jc      xStore                  ; Note: a long Y count goes back through the X store
        loop    $
        les     di,[bp+ARG_Y_RAW]
        mov     es:[di],bx              ; yRaw := count
        shr     ah,1                    ; back to the button bit
        xor     cx,cx
bLoop:
        in      al,dx
        not     al
        test    al,ah
        jnz     bDone
        loop    bLoop
        mov     al,0
        pop     bp
        ret     0Eh
bDone:
        mov     cx,BUTTON_SHIFT
        shr     al,cl                   ; align button bits into low nibble
        les     di,[bp+ARG_BUTTONS]
        mov     es:[di],al              ; buttons := bits
        mov     al,1                    ; success
        pop     bp
        ret     0Eh
READJOYSTICK    ENDP
CODE    ENDS
        END
