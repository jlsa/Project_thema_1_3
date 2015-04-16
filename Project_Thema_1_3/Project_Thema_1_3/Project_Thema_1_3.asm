/*
 * Project_Thema_1_3.asm
 *
 *  Created: 2-4-2015 10:45:15
 *  Version: 16-4-2015
 *   Author: Joël, Jari
 */ 
.include "m32def.inc"
.org 0x0000
rjmp init
.org INT0addr
rjmp change_state
.org INT1addr
rjmp change_mode
.org OC1Aaddr
rjmp tick

.cseg
.macro increment_time						; increments time, usage -> increment_time current_hours 24
	inc @0
	cpi @0, @1
	brne end_increment_time					; check for overflow
	ldi @0, 0x00
	end_increment_time:
.endmacro

.macro modulo								; modulo macro
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

.macro display_time							; display the time, insert time
	mov time, @0							; temp for time special
	rcall transmit_time						; transmit the data
.endmacro

.macro blinking_time						; display the time blinking
	cpi timer_counter1, 1					; check if can show normal time or empty
	brne show								; yes, jump to show
	rcall display_two_empty_digits			; no, then display empty
	rjmp end_blink_time

	show:
		display_time @0						; display the current hours
	end_blink_time:
.endmacro

.macro transmit_segment						; transmit a converted segment
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

init:	; Set registers to 0x00
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
	
	ldi temp, low(RAMEND)					; Load stackpointer
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

	ldi temp, high(35)						; init UART
	out UBRRH, temp							; init UART
	ldi temp, low(35)						; init UART
	out UBRRL, temp							; init UART
	ldi temp, (1 << RXEN) | (1 << TXEN)		; init UART
	out UCSRB, temp							; init UART
	ldi temp, (1 << URSEL) | (1 << UCSZ1) | (1 << UCSZ0)	; init UART
	out UCSRC, temp							; init UART
	
	ldi r16, (1<<INT1)|(1<<INT0)			; set all the interrupts
	out GICR, r16							; set int0 and int1
	
	ldi r16, (1<<ISC00)|(1<<ISC01)|(1<<ISC10)|(1<<ISC11)	; set the edge on which the interrupt should trigger
	out MCUCR, r16

	ldi r16, (1 << WGM12) | (1 << CS12) | (1 << CS10)		; set the prescaler to 1024, wgm, clock select
	out TCCR1B, r16

	ldi r16, high(10800/2) 					; 10800 = 1 second / 2 is 0.5 seconds
	out OCR1AH, r16

	ldi r16, low(10800/2)
	out OCR1AL, r16

	ldi r16, (1 << OCIE1A)
	out TIMSK, r16

	sei										; init interrupt flag in sreg

	ldi temp, 0b0000_1100					; Set lights indicating the buttons on
	out DDRB, temp
	ldi temp, 0b1111_0011
	out PORTB, temp

loop:										; do nothing here everything happens within the timer1 interrupt
	rjmp loop

tick:										; TIMER1 interrupt
	in sreg_state, SREG						; copy the SREG
	rcall update
	rcall display_state_manager
	out SREG, sreg_state					; write it back to SREG
	reti

change_state:								; int0 interrupt, change to the next state
	in sreg_state, SREG						; copy the SREG
	inc state								; go to the next state
	clr mode								; reset the mode so the other state cant do anything wrong with it.
	cpi state, 7							; if the state reaches 7 then reset it
	breq reset_state
	rjmp change_state_end

	reset_state:							; reset the state to 1 if required
		ldi state, 1						; go back to the "second" state because we dont want it to be in init mode again

	change_state_end:
		rcall display_state_manager			; refresh screen instantly, so you see the change!
		out SREG, sreg_state				; write it back to SREG
		reti

change_mode:								; int1 interrupt
	in sreg_state, SREG						; copy the SREG
	cpi state, 1							; check if state is 1, then go do state 1 stuff
	breq s1
	cpi state, 2							; check if state is 2, then go do state 2 stuff
	breq s2
	cpi state, 3							; check if state is 3, then go do state 3 stuff
	breq s3
	cpi state, 4							; check if state is 4, then go do state 4 stuff
	breq s4
	cpi state, 5							; check if state is 5, then go do state 5 stuff
	breq s5
	cpi state, 6							; check if state is 6, then go do state 6 stuff
	breq s6
	rjmp end_change_mode					; done there are no states left to check!

	s1:
		increment_time current_hours, 24
		rjmp end_change_mode
	s2:
		increment_time current_minutes, 60
		rjmp end_change_mode
	s3:
		increment_time current_seconds, 60
		rjmp end_change_mode
	s4:
		increment_time alarm_hours, 24
		rjmp end_change_mode
	s5:
		increment_time alarm_minutes, 60
		rjmp end_change_mode
	s6:
		mov temp, flags						; check if alarm is going off
		andi temp, 0b0000_1000
		cpi temp, 8
		brne s6_alarm_continue
		rcall stop_alarm
		
		s6_alarm_continue:
			mov temp, flags					; check alarm and set it if not set otherwise cancel
			andi temp, 0b0000_0001
			cpi temp, 1
			breq s6_cancel_alarm
			rcall set_alarm
			rjmp end_change_mode
		s6_cancel_alarm:
			rcall unset_alarm

	end_change_mode:
		out SREG, sreg_state				; write it back to SREG
		reti
		
update:
	state_0:								; if state = 0 then update normal clock, it just started
		cpi state, 0
		brne state_6
		rcall update_time					; just update the clock
		rjmp update_end

	state_6:								; in state 6 it shows the set alarm time and is it 
		cpi state, 6						; possible to set the alarm on and off
		brne update_end
		rcall update_time
		mov temp, flags
		andi temp, 0b0000_0001
		cpi temp, 1
		breq trigger_alarm
		rjmp update_end

		trigger_alarm:
			rcall run_alarm

	update_end:
		rcall timer_manager					; manage the timer_counter
		inc timer_counter1					; increment timer_counter
		ret

timer_manager:								; the time manager, it increments the timer counter and resets it if it reaches 2 (1 full second)
	cpi timer_counter1, 2
	breq reset_timer_counter1
	rjmp end_routine
	
	reset_timer_counter1:
		ldi timer_counter1, 0x00
		ret

update_time:
	cpi timer_counter1, 2					; is it ready to increment time?
	brne end_update							; no, then skip to the end of this routine
	rjmp increase_seconds					; yes, go to increment_seconds

	overflow_hours:							; overflow hours to zero
		ldi current_hours, 0x00
		rjmp end_routine

	increase_hours:							; increase the hours with one, if it reaches 24 it goes to overflow_hours
		ldi current_seconds, 0x00			; and set seconds and minutes to zero
		ldi current_minutes, 0x00
		inc current_hours
		cpi current_hours, 24
		breq overflow_hours
		rjmp end_routine

	increase_minutes:						; if it reached 59 then it skips this and it will go to increase_hours.
		cpi current_minutes, 59				; otherwise it will increase with one and sets seconds to zero
		breq increase_hours 
		ldi current_seconds, 0x00
		inc current_minutes
		rjmp end_routine

	increase_seconds:						; increase seconds with one only if seconds is (0 < seconds < 59) else
		cpi current_seconds, 59				; go to increase minutes
		breq increase_minutes
		inc current_seconds
		rjmp end_routine
	end_update:
		ret

display_state_manager:						; state manager for controlling which calls the right routine for showing the current state
	display_state0:							; if state 0 then display state 0 else check state 1
		cpi state, 0						
		brne display_state1
		rcall out_display_state0			; show state 0
		rjmp end_routine					; leave state manager routine

	display_state1:							; if state 1 then display state 0 else check state 2
		cpi state, 1
		brne display_state2
		rcall out_display_state1			; show state 1
		rjmp end_routine					; leave state manager routine

	display_state2:							; if state 2 then display state 0 else check state 3
		cpi state, 2
		brne display_state3
		rcall out_display_state2			; show state 2
		rjmp end_routine					; leave state manager routine

	display_state3:							; if state 3 then display state 0 else check state 4
		cpi state, 3
		brne display_state4
		rcall out_display_state3			; show state 3
		rjmp end_routine					; leave state manager routine

	display_state4:							; if state 4 then display state 0 else check state 5
		cpi state, 4
		brne display_state5
		rcall out_display_state4			; show state 4
		rjmp end_routine					; leave state manager routine

	display_state5:							; if state 5 then display state 0 else check state 6
		cpi state, 5
		brne display_state6
		rcall out_display_state5			; show state 5
		rjmp end_routine					; leave state manager routine

	display_state6:							; if state 6 then display state 0 else leave the state manager routine
		cpi state, 6
		brne end_display					; leave state manager routine
		rcall out_display_state6			; show state 6
		
		end_display:
		ret

transmit_time:								; transmit the time given in two different segments
	modulo time, 10							; split the time into two variables
	pop temp								; now its time to display to display them
	transmit_segment temp					; so transmit variable one
	pop temp								; again for variable two
	transmit_segment temp
	ret

display_additional:							; displays the two colons and the alarm if needed
	mov temp, flags
	rcall transmit
	ret

display_two_empty_digits:					; makes sure there are two digits from the seven segment display empty
	clr temp
	rcall transmit
	rcall transmit
	ret

out_display_state0:							; display the delta between start/reset of program and now blinking
	blinking_time current_hours
	blinking_time current_minutes
	blinking_time current_seconds
	rcall display_additional
	ret

out_display_state1:							; display hours blinking and the others static
	blinking_time current_hours
	out_display_s1_normal:
		display_time current_minutes
		display_time current_seconds
		rcall display_additional
	ret

out_display_state2:							; display minutes blinking and the hour and minutes static
	display_time current_hours	
	blinking_time current_minutes
	display_time current_seconds
	rcall display_additional
	ret

out_display_state3:							; display seconds blinking and the other segments static
	display_time current_hours
	display_time current_minutes
	blinking_time current_seconds
	rcall display_additional
	ret
	
out_display_state4:							; display the alarm hours blinking and the minutes static
	blinking_time alarm_hours
	display_time alarm_minutes
	rcall display_two_empty_digits
	rcall display_additional
	ret

out_display_state5:							; display the alarm minutes blinking and the hours static
	display_time alarm_hours
	blinking_time alarm_minutes
	rcall display_two_empty_digits
	rcall display_additional
	ret

out_display_state6:							; display the normal clock state
	display_time current_hours
	display_time current_minutes
	display_time current_seconds	
	rcall display_additional
	ret

transmit:									; transmits the data to the computer
	transmit_start:													
	sbis UCSRA, UDRE
	rjmp transmit_start
	out UDR, temp
	ret

convert_number:								; converts the number in temp to a binary 7 segment representation and puts it back in temp
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

set_alarm:
	sbr flags, (1 << 0)							; set the alarm bit in flags
	ret

unset_alarm:
	cbr flags, (1 << 0)							; clear the alarm bit in flags
	ret

run_alarm:
	cp alarm_hours, current_hours				; check if alarm time and normal clock are equal (Hours)
	breq check_if_minutes_trigger
	ret

	check_if_minutes_trigger:
		cp alarm_minutes, current_minutes		; check if alarm time and normal clock are equal (Minutes)
		breq check_if_second_is_zero
		ret

		check_if_second_is_zero:
			cpi current_seconds, 0
			breq really_run_alarm
			ret

			really_run_alarm:
				sbr flags, (1 << 3)				; Set the fourth bit in flags, this results in an alarm that goes off
				ret

stop_alarm:
	cbr flags, (1 << 3)							; clear bit 3 in flags. this stops the alarm
	ret

end_routine:									; this is the end for every routine, the last place it is
	ret
