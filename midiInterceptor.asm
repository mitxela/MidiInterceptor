.include "m328pdef.inc" 
	rjmp init
.org $0006
	rjmp PCINT_0
	nop
	rjmp PCINT_1
	nop
	rjmp PCINT_2
	nop



.org $0024
	rjmp USART_RXC
	nop
	rjmp USART_UDRE




.def transpose = r6

.def program = r8
.def channel = r11

.def currentController = r12

.def encButtons = r24

/*

$0100 - 127 transpose buffer (but only 37 used)
$0200 - 256 uart buffer
$0300 - previous values - 15 analog, 3 rotary, 3 buttons

$0400 - assignments. cc 1,2,5,7,64,65 at 0, others at +$80


*/
.equ pc0prev = $0300+15
.equ pc1prev = $0300+16
.equ pc2prev = $0300+17

.equ button0 = $0300+18
.equ button1 = $0300+19
.equ button2 = $0300+20





init:
	cli

	ldi r16, HIGH(RAMEND)
	out SPH,r16
	ldi r16,  LOW(RAMEND)
	out SPL,r16

	ldi r16,0b00000010
	out DDRD,r16
	ldi r16,0b11111111
	out PORTD,r16

	ldi r16,0b00111000
	out DDRB,r16

	ldi r16,0b11000110
	out PORTB,r16

	ldi r16,0b00001111
	out DDRC,r16
	
	ldi r16,0b00111111
	out PORTC,r16

	ldi r16,0
	sts PRR,r16


	ldi r16,0b11000000
	sts PCMSK2,r16

	ldi r16,0b00110000
	sts PCMSK1,r16

	ldi r16,0b00000110
	sts PCMSK0,r16

	ldi r16, 1<<PCIE2
	sts PCICR,r16




sbis PIND,5
rjmp disable





/*
	ldi XH, 1;10
longwait:
	sbiw X,1
	brne longwait
*/

	rcall defaultAssignments


	;fill datastack with activesense

	ldi YH, 2
	ldi YL, 0
	ldi r16, $FE
fillDatastackLoop:
	st Y, r16
	dec YL
	brne fillDatastackLoop





	ldi YL,0
	ldi r18,0
	clr r0
	
	ldi r21,0
	ldi r20,0

	sts pc0prev,r20
	sts pc1prev,r20
	sts pc2prev,r20

	sts button0,r20
	sts button1,r20
	sts button2,r20

	clr r3
	clr r7
	com r7
	
	clr r10
	dec r10

	clr transpose
	clr program


	ldi r16,0
	sts UBRR0H,r16
	ldi r16,15
	sts UBRR0L,r16

	ldi r16,(1<<UCSZ01|1<<UCSZ00)
	sts UCSR0C,r16

	ldi r16,(1<<RXEN0|1<<TXEN0 |1<<RXCIE0)
	sts UCSR0B,r16
	
	sei





	ldi r23,$09 ;Decode mode
	ldi r22,$FF ;Code B all digits
	rcall shiftData16

	ldi r23,$0A ;Intensity
	ldi r22,$0F
	rcall shiftData16

	ldi r23,$0B ;Scan Limit
	ldi r22,$02 ;3 digits
	rcall shiftData16

	ldi r23,$FF ;Display test
	ldi r22,$00
	rcall shiftData16

	ldi r23,$0C ;Shutdown
	ldi r22,$01 ;Normal operation
	rcall shiftData16



	ldi r20,0
	rcall displayNumber




main:

; int registers: r16,r17,r18,Y,r0

	clr r21



	ldi r20,-1
	cp r10,r20
	breq noDelayDisplay

	mov r20,r10
	rcall displayNumber
	clr r10
	dec r10


noDelayDisplay:


	in r20,PIND
	andi r20,0b11000000
	cpi r20,0b11000000
	brne turning1
	ori r21, 1<<PCIE2

turning1:
	in r20,PINC
	andi r20,0b00110000
	cpi r20,0b00110000
	brne turning2
	ori r21, 1<<PCIE1
	
turning2:
	in r20,PINB
	andi r20,0b00000110
	cpi r20,0b00000110
	brne turning3
	ori r21, 1<<PCIE0

turning3:

	sts PCICR,r21


	clr r2
	;ldi r20,0b00110000
	;mov r2,r20
adcCycle:


	mov r20,r2
	ori r20,0b00110000
	out PORTC,r20

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop



sec
sbic PIND,5
clc
ror r3



	

	ldi r20,(1<<ADLAR|1<<REFS0|1<<MUX1|1<<MUX2) ; Avcc, adc6
	sts ADMUX, r20
	ldi r20,(1<<ADEN|1<<ADSC|1<<ADIF|1<<ADPS2|1<<ADPS1|1<<ADPS0)
	sts ADCSRA,r20

waitForConversion:
	lds r20,ADCSRA
	sbrs r20,ADIF
	rjmp waitForConversion


	lds r21,ADCH

	
	ldi XH,3
	mov XL,r2
	ld r22,X
	

;	mov r22,r21

	sub r22,r21
	breq unchanged
	sbrc r22,7
	neg r22
	cpi r22,1
	breq unchanged
	

	
	
	;mov r21,r20
	st X,r21




;ldi ZH, high(ccLookup*2)
;mov ZL, r2
	ldi ZH, 4 
	mov ZL, r2
	ori ZL, $80


mov r20,r21
lsr r20
rcall displayNumber

	cli
	push YL
	mov YL,r18

	ldi r20,0b10110000
	add r20,channel
	st Y,r20
	inc YL

	ld r20,Z
	mov currentController,ZL

	st Y,r20
	inc YL
	mov r20,r21
	lsr r20
	st Y,r20
	
	subi r18,-3

	pop YL

	ldi r16,(1<<RXEN0|1<<TXEN0 |1<<RXCIE0|1<<UDRIE0)
	sts UCSR0B,r16
	sei



unchanged:

	
	inc r2


	ldi r20,15;0b00110000 + 15
	cpse r2,r20
	rjmp adcCycle




tst r3
brne buttonsHeld
ldi r21,96
mov r9,r21


buttonsHeld:
	
	
	ldi r21,0b00000101
	cp r3,r21
	brne noAssignReset
	rcall defaultAssignments
	
	ldi r23, 3
	ldi r22,10
	rcall shiftData16
	ldi r23, 2
	ldi r22,10
	rcall shiftData16
	ldi r23, 1
	ldi r22,10
	rcall shiftData16

waitForRelease:
	ldi r21,0b00000011
	
	ldi r20,0b00110001
	out PORTC,r20
	nop
	nop
	sbic PIND,5
	cbr r21,0b00000001
	ldi r20,0b00111111
	out PORTC,r20
	nop
	nop
	sbic PIND,5
	cbr r21,0b00000010
	tst r21
	brne waitForRelease


	ldi r20,0
	rcall displayNumber

	rjmp endButtons

noAssignReset:

	; r7 previous state, r21 => pressed
	mov r21,r3
	eor r21,r7
	and r21,r3
	mov r7,r3

tst r21
brne checkPressed

inc r9
breq noOverflowR9
rjmp endButtons
noOverflowR9:

ldi r21,-15
mov r9,r21

mov r21,r3


checkPressed:



;0: asssign left
;1: program up
;2: assign right
;3: octave down
;4: program down
;5: transpose down
;6: transpose up
;7: octave up

	rol r21
	brcc noOctaveUp

	ldi r20,24
	cp r20,transpose
	sbrs transpose,7
	brcs octUpLimit
	
	ldi r20,12
	add transpose,r20

octUpLimit:


	mov r20,transpose
	rcall displayNumber
	rjmp endButtons

noOctaveUp:
	rol r21
	brcc noIncTranspose	

	ldi r20,36
	cpse transpose,r20
	inc transpose

	mov r20,transpose
	rcall displayNumber
	rjmp endButtons

noIncTranspose:
	rol r21
	brcc noDecTranspose
	ldi r20,-48
	cpse transpose,r20
	dec transpose
	

	mov r20,transpose
	rcall displayNumber
	rjmp endButtons

noDecTranspose:
	rol r21
	brcc noProgDown
	
	dec program
	rjmp sendProgram

noProgDown:
	rol r21
	brcc noDecOctave

	ldi r20,-36
	cp transpose,r20
	sbrc transpose,7
	brcs octUpLimit

	ldi r20,12
	sub transpose,r20


octDownLimit:
	mov r20,transpose
	rcall displayNumber
	rjmp endButtons

noDecOctave:
	rol r21
	brcc noAssignUp


	ldi ZH,4
	mov ZL,currentController
	ld r20,Z
	inc r20
	andi r20,$7F
	st Z,r20
	rcall displayNumber


	rjmp endButtons

noAssignUp:
	rol r21
	brcc noProgUp
	
	inc program
	rjmp sendProgram

noProgUp:
	rol r21
	brcc endButtons

	ldi ZH,4
	mov ZL,currentController
	ld r20,Z
	dec r20
	andi r20,$7F
	st Z,r20
	rcall displayNumber


endButtons:



;	PD3 = polyflt
;	PD2 = arpeg onoff
;	PD4 = osc toggle

; rotary encoder buttons
	
	sbic PIND,3
	rjmp b0up
	
	sbrc encButtons,0
	rjmp checkButton1


	sbr encButtons, 0b00000001
	
	
	lds r22,button0
	com r22
	andi r22,$7F
	sts button0,r22


	ldi ZH, 4 
	ldi ZL, $80 + 18

	mov r10,r22

	cli
	push YL
	mov YL,r18

	ldi r20,0b10110000
	add r20,channel
	st Y,r20
	inc YL

	ld r20,Z
	mov currentController,ZL

	st Y,r20
	inc YL
	
	st Y,r22
	
	subi r18,-3

	pop YL

	ldi r16,(1<<RXEN0|1<<TXEN0 |1<<RXCIE0|1<<UDRIE0)
	sts UCSR0B,r16
	sei
	
	
	

	rjmp checkButton1
b0up:
	cbr encButtons, 0b00000001
	

checkButton1:

	sbic PIND,2
	rjmp b1up
	
	sbrc encButtons,1
	rjmp checkButton2


	sbr encButtons, 0b00000010
	
	
	lds r22,button1
	com r22
	andi r22,$7F
	sts button1,r22


	ldi ZH, 4 
	ldi ZL, $80 + 19

	mov r10,r22

	cli
	push YL
	mov YL,r18

	ldi r20,0b10110000
	add r20,channel
	st Y,r20
	inc YL

	ld r20,Z
	mov currentController,ZL

	st Y,r20
	inc YL
	
	st Y,r22
	
	subi r18,-3

	pop YL

	ldi r16,(1<<RXEN0|1<<TXEN0 |1<<RXCIE0|1<<UDRIE0)
	sts UCSR0B,r16
	sei
	
	
	

	rjmp checkButton2
b1up:
	cbr encButtons, 0b00000010
	

checkButton2:

	sbic PIND,4
	rjmp b2up
	
	sbrc encButtons,2
	rjmp main


	sbr encButtons, 0b00000100
	
	
	lds r22,button2
	com r22
	andi r22,$7F
	sts button2,r22


	ldi ZH, 4 
	ldi ZL, $80 + 20

	mov r10,r22

	cli
	push YL
	mov YL,r18

	ldi r20,0b10110000
	add r20,channel
	st Y,r20
	inc YL

	ld r20,Z
	mov currentController,ZL

	st Y,r20
	inc YL
	
	st Y,r22
	
	subi r18,-3

	pop YL

	ldi r16,(1<<RXEN0|1<<TXEN0 |1<<RXCIE0|1<<UDRIE0)
	sts UCSR0B,r16
	sei
	
	
	

	rjmp main
b2up:
	cbr encButtons, 0b00000100
	



	rjmp main





	; need to in sreg ?
; r0 receivepointer
; r18 endpointer
USART_RXC:
	in r1,SREG

	lds r16,UDR0
	cpi r16,$FE
	brne rcx1

	out SREG,r1
	reti
rcx1:
	push YL

	sbrs r16,7
	rjmp rcxDataByte

	mov YL,r18
	mov r0,r18

	mov r17,r16
	andi r17, $F0
	mov channel, r17
	eor channel,r16	


	mov r4,r17
	clr r5

	cpi r17, 0b11010000 ; aftertouch
	breq rcxTwoBytes	
	cpi r17, 0b11000000 ; prog change - needed?
	breq rcxTwoBytes

	inc r18

rcxTwoBytes:
	subi r18,-2
	st Y,r16
	inc r0
	pop YL

	ldi r16,(1<<RXEN0|1<<TXEN0 |1<<RXCIE0|1<<UDRIE0)
	sts UCSR0B,r16

	out SREG,r1
	reti

rcxDataByte:
	
	sbrc r5,1
	rjmp runningStatus


	mov r17,r4

	tst r5
	brne notFirstData

	cpi r17, $90 ; note on
	brne notNoteOn	
	
	ldi YH,1
	mov YL,r16
	
	add r16,transpose
	
;	mov r10,r16

	st Y, r16
	ldi YH,2

	rjmp rxDataEnd

notNoteOn:
	cpi r17,$80 ; noteoff
	brne notNoteOff
	
	ldi YH,1
	mov YL,r16
	ld r16,Y

	ldi YH,2

	rjmp rxDataEnd

notNoteOff:
	
	cpi r17, $B0
	brne rxDataEnd		;notCC
	
	mov currentController,r16

	ldi YH,4
	mov YL, r16
	ld r16,Y
	ldi YH,2

	rjmp rxDataEnd

notCC:

;	cpi r17,$C0 ; prog change
;	brne notProgChange	
;	
;	cli
;	rjmp 0
;
;notProgChange:

;	rjmp rxDataEnd

notFirstData:
	cpi r17, $B0
	brne rxDataEnd
	mov r10,r16
	

rxDataEnd:
	inc r5

	
	
	
	mov YL, r0
	st Y,r16


	inc r0
	pop YL

	ldi r16,(1<<RXEN0|1<<TXEN0 |1<<RXCIE0|1<<UDRIE0)
	sts UCSR0B,r16

	out SREG,r1
	reti
	


runningStatus:

	pop YL
	out SREG,r1
	reti



USART_UDRE:
	in r1,SREG

	ld r16, Y
	cpi r16,$FE
	brne udre1

	ldi r17,(1<<RXEN0|1<<TXEN0 |1<<RXCIE0)
	sts UCSR0B,r17

	out SREG,r1
	reti
udre1:
	sts UDR0,r16
	ldi r16, $FE
	st Y,r16
	inc YL 	; st Y+ would affect YH, we want it to wrap

;	mov r10,r0

	out SREG,r1
	reti




PCINT_0:
	in r1,SREG

	lds r16,pc0prev

	sbic PINB,1
	inc r16
	sbic PINB,2
	dec r16

;	andi r16, 0b01111111
	cpi r16, 128
	brne pc0not128
	ldi r16,127
pc0not128:
	cpi r16, -1
	brne pc0not255
	ldi r16,0
pc0not255:

	lds r17,pc0prev
	cp r17,r16
	brne pcint0b
	
	out SREG,r1
	reti

pcint0b:
	sts pc0prev,r16
	mov r10,r16

	push YL
	ldi YH,4
	ldi YL,$80+15+0
	ld r17,Y
	mov currentController,YL
	ldi YH,2

	mov YL,r18

	ldi r16,0b10110000
	add r16,channel
	st Y,r16
	inc YL

	st Y,r17
	inc YL

	st Y,r10
	
	subi r18,-3

	pop YL

	ldi r16,(1<<RXEN0|1<<TXEN0 |1<<RXCIE0|1<<UDRIE0)
	sts UCSR0B,r16



	clr r16
	sts PCICR,r16

	out SREG,r1

	reti

PCINT_1:
	in r1,SREG

	lds r16,pc1prev

	sbic PINC,5
	inc r16
	sbic PINC,4
	dec r16

	cpi r16, 128
	brne pc1not128
	ldi r16,127
pc1not128:
	cpi r16, -1
	brne pc1not255
	ldi r16,0
pc1not255:

	lds r17,pc1prev
	cp r17,r16
	brne pcint1b
	
	out SREG,r1
	reti

pcint1b:
	sts pc1prev,r16
	mov r10,r16

	push YL
	ldi YH,4
	ldi YL,$80+15+1
	ld r17,Y
	mov currentController,YL
	ldi YH,2

	mov YL,r18

	ldi r16,0b10110000
	add r16,channel
	st Y,r16
	inc YL

	st Y,r17
	inc YL

	st Y,r10
	
	subi r18,-3

	pop YL

	ldi r16,(1<<RXEN0|1<<TXEN0 |1<<RXCIE0|1<<UDRIE0)
	sts UCSR0B,r16



	clr r16
	sts PCICR,r16

	out SREG,r1

	reti



PCINT_2:
	in r1,SREG

	lds r16,pc2prev

	sbic PIND,7
	inc r16
	sbic PIND,6
	dec r16

;	andi r16, 0b01111111
	cpi r16, 128
	brne pc2not128
	ldi r16,127
pc2not128:
	cpi r16, -1
	brne pc2not255
	ldi r16,0
pc2not255:

	lds r17,pc2prev
	cp r17,r16
	brne pcint2b
	
	out SREG,r1
	reti

pcint2b:
	sts pc2prev,r16
	mov r10,r16

	push YL
	ldi YH,4
	ldi YL,$80+15+2
	ld r17,Y
	mov currentController,YL
	ldi YH,2

	mov YL,r18

	ldi r16,0b10110000
	add r16,channel
	st Y,r16
	inc YL

	st Y,r17
	inc YL

	st Y,r10
	
	subi r18,-3

	pop YL

	ldi r16,(1<<RXEN0|1<<TXEN0 |1<<RXCIE0|1<<UDRIE0)
	sts UCSR0B,r16



	clr r16
	sts PCICR,r16

	out SREG,r1
	reti






; displays r20 signed
displayNumber:
	cpi r20,-99
	brcs dispPositive
	neg r20
	ldi r22,10
	rjmp dispUnder100

dispPositive:
	ldi r22,0
	cpi r20,100
	brcs dispUnder100 
	ldi r22,1
	subi r20,100

dispUnder100:
	ldi r23,$01
	rcall shiftData16
	
	ldi r22,-1
dispCheckTens:
	inc r22
	subi r20,10
	brcc dispCheckTens
	subi r20,-10
	
	ldi r23,$02
	rcall shiftData16
	
	ldi r23,$03
	mov r22,r20
	rcall shiftData16

	ret



;CLK - green  - PB3
;DIN - orange - PB4
;LOAD- blue   - PB5

	; max7219 is MSB first
shiftData16:
	push r20
	push r21
	; data is r23:r22
	ldi r21,16
shiftBitLoop:
	cbi PORTB,3 ; clock low
	ldi r20,0b11000111
	sbrc r23,7
	ldi r20,0b11010111 ; data high 
	out PORTB,r20
	lsl r22
	rol r23
	nop
	nop
	sbi PORTB,3 ; clock high
	nop
	nop

	dec r21
	brne shiftBitLoop

	sbi PORTB,5 ;Load high
	nop
	nop
	cbi PORTB,3 ; clock low
	pop r21
	pop r20	
	ret




sendProgram:
	ldi r20,$7F
	and program,r20

	cli
	push YL
	mov YL,r18

	ldi r20,$C0
	add r20,channel
	st Y,r20
	inc YL
	st Y,program

	subi r18,-2
	pop YL

	ldi r16,(1<<RXEN0|1<<TXEN0 |1<<RXCIE0|1<<UDRIE0)
	sts UCSR0B,r16
	sei

	mov r20,program
	rcall displayNumber
	rjmp endButtons




defaultAssignments:
	
	ldi XH,4
	ldi XL,$80
	ldi ZH, high(ccLookup*2)
	ldi ZL, low(ccLookup*2)

	ldi r16,15 + 3 + 3
fillAssignLoop:
	lpm r17,Z+
	st X+,r17
	dec r16
	brne fillAssignLoop


	ldi r16,1
	sts $0401,r16
	ldi r16,2
	sts $0402,r16
	ldi r16,5
	sts $0405,r16
	ldi r16,7
	sts $0407,r16

	ldi r16,64
	sts $0400+64,r16
	ldi r16,65
	sts $0400+65,r16

	ldi r16,$7E
	sts $047E,r16
	ldi r16,$7F
	sts $047F,r16

	ret

////////////////

disable:

	clr r16
	sbic PIND,0
	ldi r16, 0b00000010

	out PORTD,r16

rjmp disable



.org 1024
ccLookup:
.db 91,13,12,16,72,93,74,94,75,95,73,70,71,76,17, 81,80,82, 83,18,19
