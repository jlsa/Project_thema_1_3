/*
 * Project_Thema_1_3.asm
 *
 *  Created: 2-4-2015 10:45:15
 *   Author: Joël, Jari
 */ 
.org 0x0000
rjmp init

.org OC1Aaddr
rjmp TIMER1_OC_ISR

.org INT0addr
rjmp BTN_SW0

.org INT1addr
rjmp BTN_SW1

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

	; Load stackpointer
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

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
		cpi current_minutes, 60
		breq increase_hours
		ldi current_seconds, 0x00
		inc current_minutes
		ldi TIMER1_OC, 0x00
		rjmp TIMER1_OC_end

	increase_seconds:
		cpi current_seconds, 60
		breq increase minutes
		inc current_seconds
		ldi TIMER1_OC, 0x00
		rjmp TIMER1_OC_end

	TIMER1_OC_end:

	; out HOURS, current_hours
	; out MINUTES, current_minutes
	; out SECONDS, current_seconds

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