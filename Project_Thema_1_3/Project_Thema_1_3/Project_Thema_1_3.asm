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
rjmp change_state

.org INT1addr
rjmp change_mode

.org OC1Aaddr
rjmp TIMER1_OC_ISR

.cseg

; modulo macro
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

; display the time
; param time to show
.macro display_time
	mov time, @0			; temp for time special
	rcall transmit_time		; transmit the data
.endmacro

; transmit a converted segment
.macro transmit_segment
	mov temp, @0
	rcall convert_number
	rcall transmit
.endmacro

.def sreg_state = r1
.def temp = r16
.def temp2 = r17
.def alarm_hours = r18
.def alarm_minutes = r19
.def current_hours = r20
.def current_minutes = r21
.def current_seconds = r22
.def state = r23
.def mode = r24
.def time = r25
; we dont use X, Y and Z so we use these registers as general purpose registers
.def flags = r26
.def timer_counter1 = r27


init:
	; Set registers to 0x00
	ldi alarm_hours, 0x00
	ldi alarm_minutes, 0x00
	ldi current_hours, 0x00
	ldi current_minutes, 0x00
	ldi current_seconds, 0x00
	ldi state, 0x00
	ldi mode, 0x00
	ldi flags, 0x00
	ldi timer_counter1, 0x00
	ldi time, 0x00
	
	; Load stackpointer
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

	; init UART
	ldi temp, high(35)
	out UBRRH, temp
	ldi temp, low(35)
	out UBRRL, temp
	
	ldi temp, (1 << RXEN) | (1 << TXEN)
	out UCSRB, temp

	ldi temp, (1 << URSEL) | (1 << UCSZ1) | (1 << UCSZ0)
	out UCSRC, temp
	
	; set all the interrupts
	ldi r16, (1<<INT1)|(1<<INT0)							; set int0 and int1
	out GICR, r16
	
	ldi r16, (1<<ISC00)|(1<<ISC01)|(1<<ISC10)|(1<<ISC11)	; set the edge on which the interrupt should trigger
	out MCUCR, r16

	; wgm, clock select
	ldi r16, (1 << WGM12) | (1 << CS12) | (1 << CS10)		; set the prescaler to 1024
	out TCCR1B, r16

	ldi r16, high(10800/2) ; 10800 = 1 second / 2 is 0.5 seconds
	out OCR1AH, r16

	ldi r16, low(10800/2)
	out OCR1AL, r16

	ldi r16, (1 << OCIE1A)
	out TIMSK, r16

	; init interrupt flag in sreg
	sei

	; Set lights indicating the buttons on
	ldi temp, 0b0000_1100
	out DDRB, temp
	ldi temp, 0b1111_0011
	out PORTB, temp

loop:
	; do nothing here everything happens within the timer1 interrupt
	rjmp loop

; TIMER1 interrupt
TIMER1_OC_ISR:
	in sreg_state, SREG						; copy the SREG

	rcall update
	rcall display_state_manager

	out SREG, sreg_state					; write it back to SREG
	reti

; change to the next state
change_state:
	in sreg_state, SREG
	inc state								; go to the next state
	clr mode								; reset the mode so the other state cant do anything wrong with it.
	cpi state, 7							; if the state reaches 7 then reset it
	breq reset_state
	rjmp change_state_end

	; reset the state to zero if required
	reset_state:
	ldi state, 1

	change_state_end:
	rcall display_state_manager
	out SREG, sreg_state
	reti

change_mode:
	in sreg_state, SREG
	inc mode	
	out SREG, sreg_state
	reti

update:
	; if state = 0 then update normal clock, it just started
	state_0:
		cpi state, 0
		brne state_1
		rcall update_time	; just update the clock
		rjmp update_end

	; in state 1 the clock is not updating, only showing 
	; the time it currently is with the hours blinking
	state_1:
		cpi state, 1
		brne state_2

		cpi mode, 1
		brge s1_increment
		rjmp update_end

		s1_increment:
			rcall increment_hours
			ldi mode, 0
			rjmp update_end

	; in state 2 the clock is not updating, only showing
	; the time it currently is with the minutes blinking
	state_2:
		cpi state, 2
		brne state_3

		cpi mode, 1
		brge s2_increment
		rjmp update_end

		s2_increment:
			rcall increment_minutes
			ldi mode, 0
			rjmp update_end
	; in state 3 the clock is not updating, only showing
	; the time it currently is with the seconds blinking
	state_3:
		cpi state, 3
		brne state_4
		cpi mode, 1
		brge s3_increment
		rjmp update_end

		s3_increment:
			rcall increment_seconds
			ldi mode, 0
			rjmp update_end

	; in state 4 the clock is not updating, only showing
	; the alarm clock time with the hours blinking
	state_4:
		cpi state, 4
		brne state_5
		cpi mode, 1
		brge s4_increment
		rjmp update_end

		s4_increment:
			rcall increment_alarm_hours
			ldi mode, 0
			rjmp update_end

	; in state 5 the clock is not updating, only showing
	; the alarm clock time with the minutes blinking
	state_5:
		cpi state, 5
		brne state_6
		cpi mode, 1
		brge s5_increment
		rjmp update_end

		s5_increment:
			rcall increment_alarm_minutes
			ldi mode, 0
			rjmp update_end

	; in state 6 it shows the set alarm time and is it 
	; possible to set the alarm on and off
	state_6:
		cpi state, 6
		brne update_end
		rcall update_time
		
		mov temp, flags
		andi temp, 0b0000_0001
		cpi temp, 1
		breq trigger_alarm
		rjmp continue_s6

		trigger_alarm:
			rcall run_alarm

		continue_s6:
		cpi mode, 1
		brge s6_alarm
		rjmp update_end

		s6_alarm:
			ldi mode, 0
			; check if alarm is going off
			mov temp, flags
			andi temp, 0b0000_1000
			cpi temp, 8
			brne s6_alarm_continue
			rcall stop_alarm
			s6_alarm_continue:
			; check alarm and set if not set otherwise cancel
			mov temp, flags
			andi temp, 0b0000_0001
			cpi temp, 1
			breq s6_cancel_alarm
			rcall set_alarm
			rjmp update_end
	
		s6_cancel_alarm:
			rcall unset_alarm
			rjmp update_end

	update_end:
		rcall timer_manager					; manage the timer_counter
		inc timer_counter1					; increment timer_counter
	ret


timer_manager:
	cpi timer_counter1, 2
	breq reset_timer_counter1
	rjmp end_timer_manager
	reset_timer_counter1:
	ldi timer_counter1, 0x00

	end_timer_manager:
	ret

update_time:
	cpi timer_counter1, 2					; is it ready to increment time?
	brne update_time_end					; no, then skip to the end of this routine
	rjmp increase_seconds					; yes, go to increment_seconds
	
	increase_hours:
		ldi current_seconds, 0x00
		ldi current_minutes, 0x00
		inc current_hours
		rjmp update_time_end

	increase_minutes:
		cpi current_minutes, 59
		breq increase_hours
		ldi current_seconds, 0x00
		inc current_minutes
		rjmp update_time_end

	increase_seconds:
		cpi current_seconds, 59
		breq increase_minutes
		inc current_seconds

	update_time_end:
	ret

; display an empty screen transmits only zero's
display_cleared:
	clr temp
	rcall display_two_empty_digits
	rcall display_two_empty_digits
	rcall display_two_empty_digits
	rcall transmit
	ret

; state manager for controlling which calls the right routine for showing the current state
display_state_manager: 
	display_state0:							; if state 0 then display state 0 else check state 1
		cpi state, 0						
		brne display_state1
		rcall out_display_state0			; show state 0
		rjmp end_display					; leave state manager routine

	display_state1:							; if state 1 then display state 0 else check state 2
		cpi state, 1
		brne display_state2
		rcall out_display_state1			; show state 1
		rjmp end_display					; leave state manager routine

	display_state2:							; if state 2 then display state 0 else check state 3
		cpi state, 2
		brne display_state3
		rcall out_display_state2			; show state 2
		rjmp end_display					; leave state manager routine

	display_state3:							; if state 3 then display state 0 else check state 4
		cpi state, 3
		brne display_state4
		rcall out_display_state3			; show state 3
		rjmp end_display					; leave state manager routine

	display_state4:							; if state 4 then display state 0 else check state 5
		cpi state, 4
		brne display_state5
		rcall out_display_state4			; show state 4
		rjmp end_display					; leave state manager routine

	display_state5:							; if state 5 then display state 0 else check state 6
		cpi state, 5
		brne display_state6
		rcall out_display_state5			; show state 5
		rjmp end_display					; leave state manager routine

	display_state6:							; if state 6 then display state 0 else leave the state manager routine
		cpi state, 6
		brne end_display					; leave state manager routine
		rcall out_display_state6			; show state 6

	end_display:
	ret

; transmit the time given in two different segments
transmit_time:
	modulo time, 10							; split the time into two variables
	pop temp								; now its time to display to display them
	transmit_segment temp					; so transmit variable one
	pop temp								; again for variable two
	transmit_segment temp
	ret

; displays the two colons and the alarm if needed
display_additional:
	mov temp, flags
	rcall transmit
	ret


; makes sure there are two digits from the seven segment display empty
display_two_empty_digits:
	clr temp
	rcall transmit
	rcall transmit
	ret

; display the delta between start/reset of program and now blinking
out_display_state0:
	cpi timer_counter1, 1
	brne display_normal_state0
	rcall display_cleared
	rjmp end_display_state0

	display_normal_state0:
		display_time current_hours
		display_time current_minutes
		display_time current_seconds
		rcall display_additional

	end_display_state0:
	ret

; display hours blinking and the others static
out_display_state1:
	cpi timer_counter1, 1
	brne out_display_s1_h
	rcall display_two_empty_digits
	rjmp out_display_s1_normal

	out_display_s1_h:
	display_time current_hours
	
	out_display_s1_normal:
		display_time current_minutes
		display_time current_seconds
		rcall display_additional
	end_out_display_state1:
	ret

; display minutes blinking and the hour and minutes static
out_display_state2:
	display_time current_hours
	cpi timer_counter1, 1
	brne out_display_s2_m
	rcall display_two_empty_digits
	rjmp out_display_s2_normal

	out_display_s2_m:
		display_time current_minutes
	
	out_display_s2_normal:
		display_time current_seconds
		rcall display_additional
	end_out_display_state2:
	ret

; display seconds blinking and the other segments static
out_display_state3:
	display_time current_hours
	display_time current_minutes

	cpi timer_counter1, 1
	brne out_display_s3_s
	rcall display_two_empty_digits
	rjmp out_display_s3_normal

	out_display_s3_s:
		display_time current_seconds
	
	out_display_s3_normal:
		rcall display_additional
	end_out_display_state3:
	ret
	
; display the alarm hours blinking and the minutes static
out_display_state4:
	cpi timer_counter1, 1
	brne out_display_s4_h
	rcall display_two_empty_digits
	rjmp out_display_s4_normal

	out_display_s4_h:
		display_time alarm_hours
	
	out_display_s4_normal:
		display_time alarm_minutes
		rcall display_two_empty_digits
		rcall display_additional
	end_out_display_state4:
	ret

; display the alarm minutes blinking and the hours static
out_display_state5:
	display_time alarm_hours
	cpi timer_counter1, 1
	brne out_display_s5_m
	rcall display_two_empty_digits
	rjmp out_display_s5_normal

	out_display_s5_m:
		display_time alarm_minutes
	
	out_display_s5_normal:
		rcall display_two_empty_digits
		rcall display_additional
	end_out_display_state5:
	ret

; display the normal clock state
out_display_state6:
	display_time current_hours
	display_time current_minutes
	display_time current_seconds	
	rcall display_additional
	ret

; transmits the data to the computer
transmit:
	transmit_start:													
	sbis UCSRA, UDRE
	rjmp transmit_start
	out UDR, temp
	ret

; converts the number in temp to a binary 7 segment representation
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

; manual time increment methods
increment_hours:
	inc current_hours
	cpi current_hours, 24						; check for overflow
	brne end_increment_hours
	ldi current_hours, 0

	end_increment_hours:
	ret

increment_minutes:
	inc current_minutes
	cpi current_minutes, 60						; check for overflow
	brne end_increment_minutes
	ldi current_minutes, 0

	end_increment_minutes:
	ret

increment_seconds:
	inc current_seconds
	cpi current_seconds, 60						; check for overflow
	brne end_increment_seconds
	ldi current_seconds, 0

	end_increment_seconds:
	ret

increment_alarm_hours:
	inc alarm_hours
	cpi alarm_hours, 24							; check for overflow
	brne end_increment_alarm_hours
	ldi alarm_hours, 0

	end_increment_alarm_hours:
	ret

increment_alarm_minutes:
	inc alarm_minutes
	cpi alarm_minutes, 60						; check for overflow
	brne end_increment_alarm_minutes
	ldi alarm_minutes, 0

	end_increment_alarm_minutes:
	ret

set_alarm:
	sbr flags, (1 << 0)			; set the alarm bit in flags
	ret
unset_alarm:
	cbr flags, (1 << 0)			; clear the alarm bit in flags
	ret

run_alarm:
	cp alarm_hours, current_hours	; check if alarm time and normal clock are equal (Hours)
	breq check_if_minutes_trigger
	rjmp end_run_alarm

	check_if_minutes_trigger:
		cp alarm_minutes, current_minutes ; check if alarm time and normal clock are equal (Minutes)
		breq check_if_second_is_zero
		rjmp end_run_alarm

		check_if_second_is_zero:
			cpi current_seconds, 0
			breq really_run_alarm
			rjmp end_run_alarm

			really_run_alarm:
				sbr flags, (1 << 3)	; Set the third bit in flags, this results in an alarm that goes off

	end_run_alarm:			
	ret

stop_alarm:
	cbr flags, (1 << 3)			; clear bit 3 in flags. this stops the alarm
	ret