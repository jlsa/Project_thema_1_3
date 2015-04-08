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
rjmp btn0

.org INT1addr
rjmp btn1

.org OC1Aaddr
rjmp TIMER1_OC_ISR

.cseg

.def temp = r16

init:
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

	cbr r16, 0b0000_0000
	;ori r16, 0b1110_1010

	rjmp loop
loop:
	; clear bit in register
	
	out PORTB, r16
	rjmp loop
end:
	rjmp end

btn0:
	sbrc r16, 4
	rjmp btn0_bit_is_set

	btn0_bit_is_clear:
	; do clear here
	sbr r16, 0b0001_0000
	rjmp interrupt_done

	btn0_bit_is_set:
	; do bit set here
	cbr r16, 0b0001_0000
	rjmp interrupt_done

btn1:
	sbrc r16, 2
	rjmp btn1_bit_is_set

	btn1_bit_is_clear:
	; do clear here
	sbr r16, 0b0000_0100
	rjmp interrupt_done

	btn1_bit_is_set:
	; do bit set here
	cbr r16, 0b0000_0100
	rjmp interrupt_done

TIMER1_OC_ISR:
	sbrc r16, 0
	rjmp timer1_bit_is_set

	timer1_bit_is_clear:
	; do clear here
	sbr r16, 0b0000_0001
	rjmp interrupt_done

	timer1_bit_is_set:
	; do bit set here
	cbr r16, 0b0000_0001
	rjmp interrupt_done

interrupt_done:
	reti
	