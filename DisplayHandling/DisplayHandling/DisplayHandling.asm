/*
Om dit te laten werken moet de stackpointer geïnitialiseerd zijn.
Ook moet de rest van de initialisatie al werken.

Alle display_xxxxx zijn subroutines voor in de main loop.
*/

.macro display
	display_macro_start:														
		sbis UCSRA, UDRE
		rjmp display_macro_start
		out UDR, @0
.endmacro

.macro modulo
	clr temp
	rjmp start
	decrease:
		inc temp
		subi @0, @1
	start:
		cpi @0, @1
		brge decrease
		push @0
		push temp
.endmacro

display_time:				; Om alles even netjes te houden
	rcall display_hours
	rcall display_minutes
	rcall display_seconds
	ret

display_nothing:
	clr temp
	ldi temp, 0x00
	display temp
	ret

display_hours:
	modulo **, 10	; Waarschijnlijk kan voor ** ook temp gebruikt worden. Zo lang het maar een register is met de uren er in.
	clr temp
	pop temp
	display temp
	clr temp
	pop temp
	display temp
	ret

display_minutes:
	modulo **, 10	; Waarschijnlijk kan voor ** ook temp gebruikt worden. Zo lang het maar een register is met de minuten er in.
	clr temp
	pop temp
	display temp
	clr temp
	pop temp
	display temp
	ret

display_seconds:
	modulo **, 10	; Waarschijnlijk kan voor ** ook temp gebruikt worden. Zo lang het maar een register is met de secondes er in.
	clr temp
	pop temp
	display temp
	clr temp
	pop temp
	display temp
	ret