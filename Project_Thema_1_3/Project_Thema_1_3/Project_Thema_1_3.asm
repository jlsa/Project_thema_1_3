.include "m32def.inc"
/*
 * Project_Thema_1_3.asm
 *
 *  Created: 2-4-2015 10:45:15
 *   Author: Joël, Jari
 */ 
.org 0x0000
rjmp init

.org INT0addr
rjmp BTN_SW0

.org INT1addr
rjmp BTN_SW1

.org OC1Aaddr
rjmp TIMER1_OC_ISR



.cseg

.macro modulo
ldi temp, 0x00
rjmp start
decrease:
	inc temp
	subi @0, @1
	rjmp start
start:
	cpi @0, @1
	brge decrease
	push temp
	push @0
.endmacro

.def temp = r16
.def compare = r17
.def alarm_hours = r18
.def alarm_minutes = r19
.def current_hours = r20
.def current_minutes = r21
.def current_seconds = r22
.def TIMER1_OC = r23
.def SW0 = r24
.def SW1 = r25

init:

	; Set compare to 0xFF to check if registers were set in main loop
	ldi compare, 0xFF
	ldi alarm_hours, 0x00
	ldi alarm_minutes, 0x00
	ldi current_hours, 0x00
	ldi current_minutes, 0x00
	ldi current_seconds, 0x00
	ldi TIMER1_OC, 0x00
	ldi SW0, 0x00
	ldi SW1, 0x00


	; Load stackpointer
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

	ldi r16, (1 << INT1) | (1 << INT0)
	out GICR, r16

	ldi r16, (1 << ISC00) | (1 << ISC01) | (1 << ISC10) | (1 << ISC11)
	out MCUCR, r16

	; wgm, clock select
	ldi r16, (1 << WGM12) | (1 << CS10) | (1 << CS12)
	out TCCR1B, r16

	ldi r16, high(10800)
	out OCR1AH, r16

	ldi r16, low(10800)
	out OCR1AL, r16

	ldi r16, (1 << OCIE1A)
	out TIMSK, r16

	sei

	ldi r16, 0b1111_1111
	out DDRB, r16


loop:
	cpse SW0, compare
	rjmp SW0_end
	; Do whatever button SW0 should do.
	ldi SW0, 0x00
	SW0_end:

	cpse SW1, compare
	rjmp SW1_end
	; Do whatever button SW1 should do.
	ldi SW1, 0x00
	SW1_end:

	cpse TIMER1_OC, compare
	rjmp TIMER1_OC_end
	; Do whatever timer1 output compare match should do.
	rjmp increase_seconds
	increase_hours:
		ldi current_seconds, 0x00
		ldi current_minutes, 0x00
		inc current_hours
		ldi TIMER1_OC, 0x00
		rjmp TIMER1_OC_end

	increase_minutes:
		cpi current_minutes, 59
		breq increase_hours
		ldi current_seconds, 0x00
		inc current_minutes
		ldi TIMER1_OC, 0x00
		rjmp TIMER1_OC_end

	increase_seconds:
		cpi current_seconds, 59
		breq increase_minutes
		inc current_seconds
		ldi TIMER1_OC, 0x00
		rjmp TIMER1_OC_end

	TIMER1_OC_end:

	; out HOURS, current_hours
	; out MINUTES, current_minutes
	; out SECONDS, current_seconds

	out PORTB, current_minutes
	rjmp loop

TIMER1_OC_ISR:
	ldi TIMER1_OC, 0xFF
	reti

BTN_SW0:
	ldi SW0, 0xFF
	reti

BTN_SW1:
	ldi SW1, 0xFF
	reti
