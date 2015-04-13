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
	
	rjmp loop


check_buttons:
	in temp, PINA
	
	out PORTB, temp
	ret