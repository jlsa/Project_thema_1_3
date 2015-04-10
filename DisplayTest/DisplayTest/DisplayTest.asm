.include "m32def.inc"

.org 0x0000
rjmp init

.org OC1Aaddr
rjmp output_compare_match

.cseg

.macro modulo
	clr temp
	mov temp2, @0
	rjmp modulo_start
	decrease:
		inc temp
		subi temp2, @1
	modulo_start:
		cpi temp2, @1
		brge decrease
		push temp2
		push temp
.endmacro

.def temp = r16
.def temp2 = r17
.def current_hours = r18
.def current_minutes = r19
.def current_seconds = r20

init:
	ldi temp, high(RAMEND)	; Initialise stackpointer
	out SPH, temp
	ldi temp, low(RAMEND)
	out SPL, temp

	ldi temp, high(35)
	out UBRRH, temp
	ldi temp, low(35)
	out UBRRL, temp
	
	ldi temp, (1 << RXEN) | (1 << TXEN)
	out UCSRB, temp

	ldi temp, (1 << URSEL) | (1 << UCSZ1) | (1 << UCSZ0)
	out UCSRC, temp

	ldi temp, (1 << WGM12) | (1 << CS12) | (1 << CS10)
	out TCCR1B, temp

	ldi temp, (1 << OCIE1A)
	out TIMSK, temp

	ldi temp, high(10800)
	out OCR1AH, temp
	ldi temp, low(10800)
	out OCR1AL, temp

	sei

	ldi current_hours, 67
	ldi current_minutes, 89
	ldi current_seconds, 11

	rjmp loop

loop:
	cpi r17, 0xFF
	brne no_interrupt
	rcall display_test
	ldi r17, 0x00

	no_interrupt:
	rjmp loop

output_compare_match:
	ldi r17,0xFF
	reti

display_test:
	clr temp
	rcall display_hours
	rcall display_minutes
	rcall display_seconds
	
	ldi temp, 0b0000_0110
	rcall display
	ret

display_hours:
	modulo current_hours, 10
	pop temp
	rcall convert_number
	rcall display
	pop temp
	rcall convert_number
	rcall display
	ret

display_minutes:
	modulo current_minutes, 10
	pop temp
	rcall convert_number
	rcall display
	pop temp
	rcall convert_number
	rcall display
	ret

display_seconds:
	modulo current_seconds, 10
	pop temp
	rcall convert_number
	rcall display
	pop temp
	rcall convert_number
	rcall display
	ret

display:
	display_start:													
	sbis UCSRA, UDRE
	rjmp display_start
	out UDR, temp
	ret

convert_number:
	check_0:
		cpi temp, 0
		brne check_1
		ldi temp, 0b0111_0111
		ret
	check_1:
		cpi temp, 1
		brne check_2
		ldi temp, 0b0010_0100
		ret
	check_2:
		cpi temp, 2
		brne check_3
		ldi temp, 0b0101_1101
		ret
	check_3:
		cpi temp, 3
		brne check_4
		ldi temp, 0b0110_1101
		ret
	check_4:
		cpi temp, 4
		brne check_5
		ldi temp, 0b0010_1110
		ret
	check_5:
		cpi temp, 5
		brne check_6
		ldi temp, 0b0110_1011
		ret
	check_6:
		cpi temp, 6
		brne check_7
		ldi temp, 0b0111_1011
		ret
	check_7:
		cpi temp, 7
		brne check_8
		ldi temp, 0b0010_0101
		ret
	check_8:
		cpi temp, 8
		brne check_9
		ldi temp, 0b0111_1111
		ret
	check_9:
		cpi temp, 9
		brne no_value
		ldi temp, 0b0110_1111
		ret
	no_value:
		ldi temp, 0b0111_0111
		ret