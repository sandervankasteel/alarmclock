/*

 Author: Sander van Kasteel, Wouter Houtsma en Vasco de Krijger
 Version: v1.0

*/
 .include "m32def.inc"
 .org 0x0000
 rjmp init

 .org OC1Aaddr					
 rjmp timer

 .equ alarmSign = 0
 .equ alarmBit = 3

 ; lets give those poor & sad anonymous registers a name shall we ? 
 .def	temp	= r16

 .def	timerS = r17
 .def	timerM = r18
 .def	timerH	= r19
 .def	alarm_s	= r20
 .def	alarm_m = r21	
 .def	alarm_h = r22

 .def	saveSR  = r23
 .def   settings= r24
 .def	mode	= r25
 .def	temp2	= r26
 .def	curLed	= r27
 .def	counter = r28

init:
	ldi  temp,high(RAMEND)				; Initialize the stack pointer
	out  SPH,temp             
	ldi  temp,low(RAMEND)       
	out  SPL,temp 
	
	ldi mode, 0
	ldi counter, 0
	clr temp							; clear tmp
	out UBRRH, temp						; Sets the value in temp to the UBRRH port
	ldi temp, 35						; The 35 equals the 19200 Baud (See page 167 of the datasheet)
	out UBRRL, temp
	
	ldi temp, (1<<URSEL)|(1<<UCSZ1)|(1<<UCSZ0) ; set frame format : asynchronous, parity disabled, 8 data bits, 1 stop bit
	out UCSRC, temp
	
	
	ldi temp, (1 << RXEN) | (1 << TXEN) ; enable receiver & transmit on the RS232 port
	out UCSRB, temp
	
	;init port
	ser temp							; sets temp to 0xFF
	out DDRB, temp						; Port B is output port
	out PORTB, temp						; Turn the leds off
	clr temp							; clear temp
	out DDRD, temp						; outputs the value of temp to DDRB
	out DDRA, temp						; outputs the value of temp to DDRA
	
	;init timer
	ldi temp, high(8640)				; sets the prescale to 8640 which is 1/4 of 1 second (43200 is 1 sec with a prescaler of 256)
	out OCR1AH, temp					
	ldi temp, low(8640)
	out OCR1AL, temp
	

	ldi temp, (1 << CS12) | (1 << WGM12); put the timer into ctc mode and apply a prescaler of 256
	out TCCR1B, temp
	
	ldi temp, (1 << OCIE1A)				; enable interrupt 1
	out TIMSK, temp						; set the value of temp to the outport
	clr temp							; clear temp

	ldi settings, 0b00000111			; loads the value of 0b00000110 in the settings register
	;ldi settings, 0b01110110
								
	ldi timerM, 0					; put in some default values for timerM
	ldi timerH, 0					; put in some default values for timerH
	ldi timerS, 0					; put in some default values for timerS
	ldi alarm_s, 0						; put in some default values for alarmS
	ldi alarm_m, 0					; put in some default values for alarmM
	ldi alarm_h, 0					; put in some default values for alarmH
		
	sei									; enable interrupts

loop:							
	rjmp loop

setLeds:
	out PORTB, curLed					; sets the value of curLed to PORTB
ret

telop:
	rcall increment_second				; call increment_second
	ldi counter, 0						; loads an 0 in counter
	rjmp returnToTimer					; jumps to returnToTime

timer:							
	in saveSR, SREG						; save StatusRegister to saveSR 
	rcall checkAlarm					; calls checkAlarm
	rcall updateTime					; call de updateTime checks
	rcall sendTime						; call sendTime
	cpi mode, 0 
	breq setAlarm
	continueTimerAfterAlarm:

	inc counter							; increments counter
	cpi counter, 5						; compares counter to 5
	breq telop							; branches to telop if its equal to 5

	returnToTimer:
	out SREG, saveSR					; puts the StatusRegister back from saveSR
reti

setAlarm:
	rcall alarmSet
	rjmp continueTimerAfterAlarm
alarmSet:
	in temp, PINA						; read input from portA
	cpi temp, 0b11111110				; compare
	brne endAlarmSet

	cpi mode, 1
	breq endAlarmSet

		sbrs settings, 0
		rjmp alarmOn
		sbrc settings, 0
		rjmp alarmOff
	ret
		alarmOn:
			sbr settings, (1<<alarmSign)
		ret

	alarmOff:
		cbr	settings, (1<<alarmSign)
		cbr settings, (1<<alarmBit)
	endAlarmSet:
ret

updateMode:
	inc mode							; increment the mode register
	ldi temp, 6							; load 6 into the temp register
	cpse temp, mode						; compare temp and mode
	rjmp endUpdate						; if true, jump to endUpdate
	ldi mode, 0							; load 0 into the mode register
	rjmp endUpdate						; rjmp to endUpdate

updateTime:
	in temp, PINA						; read the input of PINA and load that value in temp
	cpi temp, 0b11111101				; compare temp with 0b11111101
	breq updateMode						; if equals then branch to updateMode
	
	cpi temp, 0b11111110				; compare temp with 0b11111110
	breq tussenstap						; branch to tussenStap

	endUpdate:
	ldi curLed, 0b11111111				; load 0b11111111 into the curLed register
	rcall setLeds						; rcall setLeds
	
	cpi mode, 0							; compare mode to 0
	breq returnFromUpdate				; if equals then branch to returnFromUpdate
	ldi curLed, 0b01011111				; load 0b01011111 into curLed register
	rcall setLeds						; calls setLeds
	
	cpi mode, 1							; compare mode register to 1
	breq returnFromUpdate				; branch if equals to returnFromUpdate
	ldi curLed, 0b01101111				; load 0b01101111 into curLed
	rcall setLeds						; calls setLeds
	
	cpi mode, 2							; compares mode register to 2
	breq returnFromUpdate				; if this is true then branch to returnFromUpdate
	ldi curLed, 0b01110111				; loads 0b01110111 into curLed
	rcall setLeds						; calls setLeds
	
	cpi mode, 3							; compare mode register to 3
	breq returnFromUpdate				; if this is true then brancht to returnFromUpdate
	ldi curLed, 0b00011111				; load 0b00011111 into curLed
	rcall setLeds						; calls setLeds
	
	cpi mode, 4							; compare mode register to 4
	breq returnFromUpdate				; if this is equal then branch to returnFromUpdate
	ldi curLed, 0b00101111				; loads 0b00101111 into the curLeds register
	rcall setLeds						; calls setLeds
	
	cpi mode, 5							; compares mode register to 5
	breq returnFromUpdate				; if this is equal then branch to returnFromUpdate
	ldi curLed, 0b00110111				; loads 0b00110111 into the curLeds register
	rcall setLeds						; calls setLeds
	
	cpi mode, 6							; compares mode register to 6
	breq returnFromUpdate				; always branch to returnFromUpdate

	returnFromUpdate:
ret
	
increment_alarm_second:
	inc alarm_s							; increment timerS
	cpi alarm_s	, 0x5A					; Compare timerS to 60
	breq increment_alarm_minute			; If true, jump incMinute
	swap alarm_s						; swap here to save registers
	cpi alarm_s	, 0xA0					; compares alarm_s register to an inverted 10
	brlo endIncSecal					; branch if lower then an inverted 10 to endIncSecal

		incSecTenal:			
			andi alarm_s, 0x0F			; does an AND + increment on the alarm_s register
			inc alarm_s					; increments the alarm_s register
			swap alarm_s				; swaps alarm_s register
		ret								; returns from the calll

	endIncSecal:						
	swap alarm_s						; swap back
	ret
increment_alarm_minute:
	clr alarm_s							; first off all, lets clear the alarm_s register
	inc alarm_m							; increment the alarm_m register
	cpi alarm_m, 0x5A					; then compare it to 60
	breq increment_alarm_hour			; branches if equal to increment_alarm_hour
	swap alarm_m						; swap alarm_m
						
	cpi alarm_m, 0xA0					; compare alarm_m to 10
	brlo endIncMinal					; if lower then 10 then branch to endIncMinal
		
		incMinTenal:		
			andi alarm_m, 0x0F			; does logical AND and loads 0x0F on the alarm_m register
			inc alarm_m					; increments alarm_m
			swap alarm_m				; swap back :)
		ret								; now return back to the call place

		endIncMinal:
		swap alarm_m					; swaps back if nothing is needed
ret

tussenstap:								; this implemented because of the limit of rcall
	rcall incrementTime					; rcall incrementTime
	rjmp endUpdate						; jumps to endUpdate 

increment_alarm_hour:
	clr alarm_m							; clear the alarm_m register
						
	inc alarm_h							; increment alarm_h register
	cpi alarm_h, 0x24					; compare to 24
	breq reset_clockal					; if alarm_h equals 24 then branch to reset_clockal
	swap alarm_h						; swap alarm_h
								
	cpi alarm_h, 0xA0					; compare alarm_h to 10
	brlo endIncHoural					; if alarm_h is lower then 10 branch to endIncHoural

		incHourTenal:
			andi alarm_h, 0x0F			; logical AND with Immediate on alarm_h
			inc alarm_h					; incremetns alarm_h register
			swap alarm_h				; swaps the alarm_h bac
		ret
										
		reset_clockal:
			clr timerS					; clears timerS register
			clr alarm_m					; clears alarm_m register
			clr alarm_h					; clears alarm_h register
		ret

		endIncHoural:
			swap alarm_h				; swap alarm_h back
		ret
incTimeClockHour:
	rcall increment_hour				; calls increment_hour
	rjmp end							; jumps to the 'end' label

incTimeClockMinute:
	rcall incMinute						; calls incMinute
	rjmp end							; jumps to the 'end' label

incTimeClockSecond:
	rcall increment_second				; calls increment_send
	rjmp end							; jumps to the 'end' label

incTimeAlarmHour:
	rcall increment_alarm_hour			; calls increment_alarm_hour
	rjmp end							; jumps to the 'end' label

incTimeAlarmMinute:
	rcall increment_alarm_minute		; calls increment_alarm_minute
	rjmp end							; jumps to the 'end' label

incTimeAlarmSecond:
	rcall increment_alarm_second		; calls increment_alarm_second
	rjmp end							; jumps to the 'end' label

checkAlarm:
	sbrs settings, (1<<alarmSign)				; if not equal, then jump to noAlarm
	rjmp noAlarm
	cp alarm_h, timerH							; compare alarm_h with timerH
	brne noAlarm								; if not equal, then jump to noAlarm
	cp alarm_m, timerM							; compare alarm_m with timerM
	brne noAlarm								; if not equal then jump to noAlarm

	yesAlarm:
		;ldi temp, 0b00000101					; sets alarm to go woop woop woop woop
		; settings, temp						; adds temp register with settings register and puts the value of those two in settings
		
		sbr settings, (1<<alarmBit)
		
		
		ret				
	noAlarm:
ret
incrementTime:
	cpi mode, 0									; compares mode with 0
	breq end									; this is equal then jump to 'end' label

	cpi mode, 1									; compares mode with 1
	breq incTimeClockHour						; this is equal then branches to incTimerClockHour

	cpi mode, 2									; compares mode with 2
	breq incTimeClockMinute						; this is equal then branches to incTimerClockMinute

	cpi mode, 3									; compares mode with 3				
	breq incTimeClockSecond						; this is equal then branches to incTimerClockSecond

	cpi mode, 4									; compares mode with 4
	breq incTimeAlarmHour						; this is equal then branches to incTimeAlarmHour

	cpi mode, 5									; compares mode with 5
	breq incTimeAlarmMinute						; this is equal then branches to incTimerAlarmMinute

	cpi mode, 6									; compares mode with 6
	breq incTimeAlarmSecond						; this is equal then branches to incTimerAlarmSecond
	;breq alarmStatus							; if this is equal then branches to alarmStatus

	end:									
	rjmp endUpdate								; jumps to endUpdate


increment_second:
						
	inc timerS									; increment timerS
	cpi timerS, 0x5A							; Compare timerS to 60
	breq incMinute								; If true, jump incMinute
	swap timerS									; swaps timerS register
	cpi timerS, 0xA0							; compares timerS to 10
	brlo endIncSec								; branches if lower then 10 to endIncSec

		incSecTen:			
			andi timerS, 0x0F					; does a logical AND with immediate on timerS
			inc timerS							; increments timerS
			swap timerS							; swaps timerS register back
		ret

	endIncSec:
	swap timerS									; swap back
ret

incMinute:		
	clr timerS									; clear timerS register
	inc timerM									; increments the timerM register
	cpi timerM, 0x5A							; compare the timerM register with 60
	breq increment_hour							; branches if timerM is equal to 60
	swap timerM									; swap timerM
						
	cpi timerM, 0xA0							; compares timerM with A0
	brlo endIncMin								; if it's lower then branch to endIncMin
		
		incMinTen:
			andi timerM, 0x0F					; does a logical AND with immediate on timerM
			inc timerM							; increments timerM
			swap timerM							; swaps timerM back
		ret 

		endIncMin:
		swap timerM								; swaps timerM back
ret

increment_hour:	
	clr timerM									; clear the timerM register
						
	inc timerH									; increment timerH
	cpi timerH, 0x24							; comapre timerH with 24
	breq reset_clock							; if this is equal to 24 then branch to reset_clock
	swap timerH									; swaps timerH
										
	cpi timerH, 0xA0							; compares with timerH with 0xA0 (inverted 10)
	brlo endIncHour
		
		incHourTen:
			andi timerH, 0x0F					; does an logical AND with immediate on timerH
			inc timerH							; increments timerH
			swap timerH							; swaps timerH
		ret
		reset_clock:
			clr timerS							; clears timerS register
			clr timerM							; clears timerM register
			clr timerH							; clears timerH
		ret
		endIncHour:
		swap timerH								; swaps back the timerH register
ret

sendTime:
	cpi mode, 4									; compares with the mode register with 4
	brge sendAlarm								; if this is equal to 4 then branch to sendAlarm

	mov temp, timerH							; copies the value of timerH to temp
	swap temp									; swap temp
	andi temp, 0x0F								; do a logical AND with immediate on temp
	rcall convertToSeg							; calls converToSeg
	rcall sendRS232								; Now lets send this ;)

	mov temp, timerH							; copies the value of timerH again to temp
	andi temp, 0x0F								; do a logical AND with immediate on temp
	rcall convertToSeg							; calls converToSeg
	rcall sendRS232								; Now lets send this ;)

	mov temp, timerM							; copies the value of timerM to temp
	swap temp									; swap temp
	andi temp, 0x0F								; do a logical AND with immediate on temp
	rcall convertToSeg							; calls converToSeg
	rcall sendRS232								; Now lets send this ;)

	mov temp, timerM							; copies the value of timerMS again to temp
	andi temp, 0xF								; do a logical AND with immediate on temp
	rcall convertToSeg							; calls converToSeg	
	rcall sendRS232								; Now lets send this ;)

	mov temp, timerS							; copies the value of timerS to temp
	swap temp									; swap temp
	andi temp, 0x0F								; do a logical AND with immediate on temp
	rcall convertToSeg							; calls converToSeg
	rcall sendRS232								; Now lets send this ;)
	
	mov temp, timerS							; copies the value of timerS again to temp
	andi temp, 0x0F								; do a logical AND with immediate on temp
	rcall convertToSeg							; calls converToSeg
	rcall sendRS232								; Now lets send this ;)

	mov temp, settings							; Copies the value of settings to temp SIDE NOTE : dubbelpunt aan
	rcall sendRS232								; Now lets send this ;)

	endSendTime:
ret

sendAlarm:
	
	mov temp, alarm_h							; copies the value of alarm_h to temp
	swap temp									; swap temp
	andi temp, 0x0F								; do a logical AND with immediate on temp
	rcall convertToSeg							; calls converToSeg
	rcall sendRS232								; Now lets send this ;)

	mov temp, alarm_h							; copies the value of alarm_h again to temp
	andi temp, 0x0F								; do a logical AND with immediate on temp
	rcall convertToSeg							; calls converToSeg
	rcall sendRS232								; Now lets send this ;)

	mov temp, alarm_m							; copies the value of alarm_m to temp
	swap temp									; swap temp
	andi temp, 0x0F								; do a logical AND with immediate on temp
	rcall convertToSeg							; calls converToSeg
	rcall sendRS232								; Now lets send this ;)
											
	mov temp, alarm_m							; copies the value of alarm_m again to temp
	andi temp, 0xF								; do a logical AND with immediate on temp
	rcall convertToSeg							; calls converToSeg	
	rcall sendRS232								; Now lets send this ;)
																							
	mov temp, alarm_s							; copies the value of alarm_s to temp
	swap temp									; swap temp
	andi temp, 0x0F								; do a logical AND with immediate on temp
	rcall convertToSeg							; calls converToSeg
	rcall sendRS232								; Now lets send this ;)
												
	mov temp, alarm_s							; copies the value of alarm_s again to temp
	andi temp, 0x0F								; do a logical AND with immediate on temp
	rcall convertToSeg							; calls converToSeg
	rcall sendRS232								; Now lets send this ;)
												
	mov temp, settings							; Copies the value of settings to temp SIDE NOTE : dubbelpunt aan
	rcall sendRS232								; Now lets send this ;)
								
	rjmp endSendTime							; jumps to endSendTime (in the sendTime function)

sendRS232:														
	sbis UCSRA, UDRE							; skips if both bits are set (aka RS232 buffer isnt ready yet)
	rjmp sendRS232								; if that is the case then jump back to the begin of this function
	out UDR, temp								; if not then put the value of temp into the UDR register
ret


convertToSeg:
	cpi temp, 0
	breq set_0

	cpi temp, 1
	breq set_1

	cpi temp, 2
	breq set_2

	cpi temp, 3
	breq set_3

	cpi temp, 4
	breq set_4

	cpi temp, 5
	breq set_5

	cpi temp, 6
	breq set_6

	cpi temp, 7
	breq set_7

	cpi temp, 8
	breq set_8

	cpi temp, 9
	breq set_9
ret

set_0:
	ldi temp, 0x77
ret

set_1:
	ldi temp, 0x24
ret

set_2:
	ldi temp, 0x5D
ret

set_3:
	ldi temp, 0x6D
ret

set_4:
	ldi temp, 0x2E
ret

set_5:
	ldi temp, 0x6B
ret

set_6:
	ldi temp, 0x7B
ret

set_7:
	ldi temp, 0x25
ret

set_8:
	ldi temp, 0x7F
ret

set_9:
	ldi temp, 0x6F
ret