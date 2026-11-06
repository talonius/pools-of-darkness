; The INT 66h sound-driver interface, appended to SoundDrv's code by {$L SOUNDDRV.OBJ}.  Pascal calls the public
; procedures with a push of CS and a near call, so they return far; the private probe returns near to DriverPresent.
;
; DriverDispatch submits command 0688h when AX is nonzero; DriverBusy submits 0689h.  DriverPresent reads interrupt
; vector 66h and recognizes the KERN signature stored six bytes before the handler.
CODE	SEGMENT BYTE PUBLIC 'CODE'
	ASSUME	CS:CODE, DS:CODE
	PUBLIC	DriverDispatch
	PUBLIC	DriverBusy
	PUBLIC	DriverPresent
DRIVER_INT	EQU	66h
DRIVER_VECTOR	EQU	DRIVER_INT * 4
DRIVER_SEND_CMD	EQU	0688h
DRIVER_POLL_CMD	EQU	0689h
KERN_SIG_LO	EQU	454Bh
KERN_SIG_HI	EQU	4E52h
KERN_SIG_BACKOFF	EQU	6
DriverDispatch:
	push	bp
	mov	bp,sp
	push	es
	push	ds
	push	si
	push	di
	cld
	or	ax,ax
	jz	driverSendDone
	mov	ax,DRIVER_SEND_CMD
	mov	si,[bp+6]
	int	DRIVER_INT
	mov	ax,1
driverSendDone:
	pop	di
	pop	si
	pop	ds
	pop	es
	pop	bp
	retf	2
DriverBusy:
	push	bp
	mov	bp,sp
	mov	ax,DRIVER_POLL_CMD
	int	DRIVER_INT
	pop	bp
	retf
DriverPresent:
	push	bp
	mov	bp,sp
	call	driverReadyProbe
	pop	bp
	retf
driverReadyProbe:
	push	bp
	mov	bp,sp
	push	ds
	push	si
	mov	si,DRIVER_VECTOR
	xor	ax,ax
	mov	ds,ax
	lds	si,[si]
	or	si,si
	jz	driverNotReady
	sub	si,KERN_SIG_BACKOFF
	cmp	word ptr [si],KERN_SIG_LO
	jne	driverNotReady
	cmp	word ptr [si+2],KERN_SIG_HI
	jne	driverNotReady
	mov	ax,1
driverReadyReturn:
	pop	si
	pop	ds
	pop	bp
	ret
driverNotReady:
	xor	ax,ax
	jmp short driverReadyReturn
CODE	ENDS
	END
