.include "m32def.inc"
/*
 * Project_Thema_1_3.asm
 *
 *  Created: 2-4-2015 10:45:15
 *   Author: Joël, Jari
 */ 
.org 0x0000
rjmp init

.def temp = r16
.def counter = r24 
.cseg

init:
	ser temp
	
	out PORTB, temp
	out DDRB, temp
	out PORTA, temp

	clr temp
	out DDRA, temp
	rjmp loop

loop:
	rcall check_buttons
	/*sw0:
	sbic PINA, 0
	rjmp sw1
	dec counter
	;ldi temp, 0b1111_0000
	;out PORTB, temp

	sw1:
	sbic PINA, 1
	rjmp sw0
	inc counter
	;ldi temp, 0b0000_1111
	;out PORTB, temp
	
	out PORTB, counter*/
	rjmp loop


check_buttons:
IN		temp,	PINA
COM		temp
OUT		PORTB,	temp
CPI		temp,	0b01
BREQ	checkbuttons_mode
CPI		temp,	0b10
BREQ	checkbuttons_cycle
RET
checkbuttons_mode:
RCALL	IncrementMode
RET
checkbuttons_cycle:
RCALL	Increment_Applicable_Time
RCALL	Send

RET