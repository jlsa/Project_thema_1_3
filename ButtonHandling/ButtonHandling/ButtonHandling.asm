check_buttons:
	clr temp
	in temp, PINA				; Ik geloof dat het A is, weet ik niet zeker
	cpi temp, 0b1111_1110
	brne check_button_SW1
	; Set a bit in a register
	rjmp check_button_end

	check_button_SW1:
	cpi temp, 0b1111_1101
	brne check_button_end
	; Set a bit in a register
	check_button_end:
	ret

; Aan de hand van het bitje kunnen we dingen gaan doen. Dus in principe moet je gwn testen of het bitje geset is.