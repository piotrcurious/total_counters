; PIC12F629 code implementing device on/off cycle counter
; The device should read last total on/off cycle count upon each reset (power on) , increment it and store it back into eeprom.
; uint32 should be used for the counter.
; Then the device should emit current cycle count using serial output and loop forever .
; Use wear levelling to reduce eeprom wear by reading all numbers in the eeprom , determining which one is the highest and writing back incremented number in a next address, or first address if it was last address.
; Use macros for 32bit arithmetic operations used to make code easily readable and compact.

list p=12F629 ; specify the device
include "p12f629.inc" ; include the device header file
__CONFIG _MCLRE_OFF & _CP_OFF & _WDT_OFF & _INTRC_OSC_NOCLKOUT ; set the configuration bits

; define some constants
#define EEPROM_SIZE 128 ; size of the eeprom in bytes
#define EEPROM_MASK 0x7F ; mask for the eeprom address
#define BAUD_RATE 9600 ; baud rate for serial communication
#define DIVIDER (((_XTAL_FREQ/BAUD_RATE)/4)-1) ; divider for the timer0
#define _XTAL_FREQ 4000000 ; oscillator frequency in Hz

; define some macros for 32-bit arithmetic operations
; the operands are four bytes each: A3:A2:A1:A0 and B3:B2:B1:B0
; the result is stored in R3:R2:R1:R0
; the carry flag is used for intermediate calculations
; the zero flag is set if the result is zero

; macro for 32-bit addition: R = A + B
ADD32 MACRO A3, A2, A1, A0, B3, B2, B1, B0, R3, R2, R1, R0
    clrf R3 ; clear the result
    clrf R2
    clrf R1
    clrf R0
    movf A0, w ; add the least significant bytes
    addwf B0, w
    movwf R0 ; store the result
    btfsc STATUS, C ; check the carry flag
    incf R1, f ; increment the next byte if carry
    movf A1, w ; add the next bytes
    addwf B1, w
    movwf R1 ; store the result
    btfsc STATUS, C ; check the carry flag
    incf R2, f ; increment the next byte if carry
    movf A2, w ; add the next bytes
    addwf B2, w
    movwf R2 ; store the result
    btfsc STATUS, C ; check the carry flag
    incf R3, f ; increment the next byte if carry
    movf A3, w ; add the most significant bytes
    addwf B3, w
    movwf R3 ; store the result
    btfsc STATUS, C ; check the carry flag
    bsf R3, 7 ; set the sign bit if overflow
    movf R3, w ; check if the result is zero
    iorwf R2, w
    iorwf R1, w
    iorwf R0, w
    btfss STATUS, Z ; skip if zero
    bsf R3, 6 ; set the zero bit if zero
    ENDM

; macro for 32-bit increment: R = A + 1
INC32 MACRO A3, A2, A1, A0, R3, R2, R1, R0
    ADD32 A3, A2, A1, A0, 0, 0, 0, 1, R3, R2, R1, R0 ; use the addition macro with B = 1
    ENDM

; macro for 32-bit comparison: A - B
; the zero flag is set if A = B
; the carry flag is set if A < B
; the sign flag is set if A > B
CMP32 MACRO A3, A2, A1, A0, B3, B2, B1, B0
    movf B0, w ; subtract the least significant bytes
    subwf A0, w
    btfsc STATUS, C ; check the carry flag
    incf A1, f ; borrow from the next byte if carry
    movf B1, w ; subtract the next bytes
    subwf A1, w
    btfsc STATUS, C ; check the carry flag
    incf A2, f ; borrow from the next byte if carry
    movf B2, w ; subtract the next bytes
    subwf A2, w
    btfsc STATUS, C ; check the carry flag
    incf A3, f ; borrow from the next byte if carry
    movf B3, w ; subtract the most significant bytes
    subwf A3, w
    btfss STATUS, C ; skip if carry
    bsf STATUS, N ; set the sign flag if no carry
    movf A3, w ; check if the result is zero
    iorwf A2, w
    iorwf A1, w
    iorwf A0, w
    btfss STATUS, Z ; skip if zero
    bcf STATUS, N ; clear the sign flag if zero
    ENDM

; define some variables in the general purpose registers
CBLOCK 0x20
    counter3 ; the most significant byte of the counter
    counter2
    counter1
    counter0 ; the least significant byte of the counter
    temp3 ; temporary variables for calculations
    temp2
    temp1
    temp0
    eeadr ; the eeprom address
    eedata ; the eeprom data
    maxaddr ; the eeprom address with the highest counter value
    maxdata3 ; the most significant byte of the highest counter value
    maxdata2
    maxdata1
    maxdata0 ; the least significant byte of the highest counter value
    bitcnt ; the bit counter for serial output
    ENDC

; initialize the device
    org 0 ; start at the beginning of the program memory
    bsf STATUS, RP0 ; select bank 1
    movlw b'00001000' ; set GP3 as input and GP0-GP2 as output
    movwf TRISIO
    movlw b'00000000' ; enable the weak pull-ups on GP3
    movwf OPTION_REG
    movlw b'00000000' ; disable the comparator module
    movwf CMCON
    bcf STATUS, RP0 ; select bank 0
    clrf GPIO ; clear the output pins
    clrf TMR0 ; clear the timer0
    clrf counter3 ; clear the counter
    clrf counter2
    clrf counter1
    clrf counter0
    clrf maxaddr ; clear the max address
    clrf maxdata3 ; clear the max data
    clrf maxdata2
    clrf maxdata1
    clrf maxdata0

; read the last total on/off cycle count from the eeprom
read_eeprom
    movf eeadr, w ; load the eeprom address
    movwf EEADR ; store it in the eeprom register
    bsf STATUS, RP0 ; select bank 1
    bsf EECON1, RD ; start the read operation
    bcf STATUS, RP0 ; select bank 0
    movf EEDATA, w ; get the eeprom data
    movwf eedata ; store it in the variable
    andlw 0x0F ; mask the lower nibble
    movwf temp0 ; store it in the least significant byte of the temp variable
    swapf eedata, w ; swap the nibbles of the eeprom data
    andlw 0x0F ; mask the lower nibble
    movwf temp1 ; store it in the next byte of the temp variable
    incf eeadr, f ; increment the eeprom address
    andlw EEPROM_MASK ; mask the address
    movwf EEADR ; store it in the eeprom register
    bsf STATUS, RP0 ; select bank 1
    bsf EECON1, RD ; start the read operation
    bcf STATUS, RP0 ; select bank 0
    movf EEDATA, w ; get the eeprom data
    movwf eedata ; store it in the variable
    andlw 0x0F ; mask the lower nibble
    movwf temp2 ; store it in the next byte of the temp variable
    swapf eedata, w ; swap the nibbles of the eeprom data
    andlw 0x0F ; mask the lower nibble
    movwf temp3 ; store it in the most significant byte of the temp variable
    CMP32 temp3, temp2, temp1, temp0, maxdata3, maxdata2, maxdata1, maxdata0 ; compare the temp variable
        ; compare the temp variable with the max data
    btfss STATUS, Z ; skip if equal
    btfsc STATUS, N ; skip if greater
    goto update_max ; update the max data if less
    goto next_addr ; go to the next address otherwise
update_max
    movf eeadr, w ; get the current eeprom address
    sublw 2 ; subtract 2 to get the previous address
    andlw EEPROM_MASK ; mask the address
    movwf maxaddr ; store it in the max address variable
    movf temp3, w ; get the most significant byte of the temp variable
    movwf maxdata3 ; store it in the max data variable
    movf temp2, w ; get the next byte of the temp variable
    movwf maxdata2 ; store it in the max data variable
    movf temp1, w ; get the next byte of the temp variable
    movwf maxdata1 ; store it in the max data variable
    movf temp0, w ; get the least significant byte of the temp variable
    movwf maxdata0 ; store it in the max data variable
next_addr
    movf eeadr, w ; get the current eeprom address
    xorlw EEPROM_MASK ; check if it is the last address
    btfss STATUS, Z ; skip if not
    goto end_read ; end the read operation if yes
    incf eeadr, f ; increment the eeprom address otherwise
    goto read_eeprom ; repeat the read operation

; increment the counter and store it back into the eeprom
end_read
    INC32 maxdata3, maxdata2, maxdata1, maxdata0, counter3, counter2, counter1, counter0 ; increment the max data and store it in the counter variable
    movf maxaddr, w ; get the max address
    incf w, f ; increment it
    andlw EEPROM_MASK ; mask it
    movwf eeadr ; store it in the eeprom address variable
    movf counter0, w ; get the least significant byte of the counter
    andlw 0x0F ; mask the lower nibble
    movwf eedata ; store it in the eeprom data variable
    swapf counter0, w ; swap the nibbles of the counter
    andlw 0x0F ; mask the lower nibble
    iorwf eedata, f ; or it with the eeprom data
    bsf STATUS, RP0 ; select bank 1
    bcf EECON1, EEPGD ; select the data memory
    bcf EECON1, WREN ; disable the write operation
    bcf INTCON, GIE ; disable the global interrupt
    bcf EECON1, WR ; clear the write bit
    bcf EECON1, WRERR ; clear the write error bit
    bcf PIR1, EEIF ; clear the write done flag
    bsf EECON1, WREN ; enable the write operation
    movf eeadr, w ; load the eeprom address
    movwf EEADR ; store it in the eeprom register
    movf eedata, w ; load the eeprom data
    movwf EEDATA ; store it in the eeprom register
    movlw 0x55 ; load the first unlock sequence
    movwf EECON2 ; store it in the eeprom register
    movlw 0xAA ; load the second unlock sequence
    movwf EECON2 ; store it in the eeprom register
    bsf EECON1, WR ; start the write operation
    btfsc EECON1, WR ; wait until the write is done
    goto $-1
    bcf EECON1, WREN ; disable the write operation
    bcf PIR1, EEIF ; clear the write done flag
    bcf EECON1, WR ; clear the write bit
    bcf EECON1, WRERR ; clear the write error bit
    bsf INTCON, GIE ; enable the global interrupt
    bcf STATUS, RP0 ; select bank 0
    incf eeadr, f ; increment the eeprom address
    andlw EEPROM_MASK ; mask it
    movwf EEADR ; store it in the eeprom register
    movf counter1, w ; get the next byte of the counter
    andlw 0x0F ; mask the lower nibble
    movwf eedata ; store it in the eeprom data variable
    swapf counter1, w ; swap the nibbles of the counter
    andlw 0x0F ; mask the lower nibble
    iorwf eedata, f ; or it with the eeprom data
    bsf STATUS, RP0 ; select bank 1
    bcf EECON1, EEPGD ; select the data memory
    bcf EECON1, WREN ; disable the write operation
    bcf INTCON, GIE ; disable the global interrupt
    bcf EECON1, WR ; clear the write bit
    bcf EECON1, WRERR ; clear the write error bit
    bcf PIR1, EEIF ; clear the write done flag
    bsf EECON1, WREN ; enable the write operation
    movf eeadr, w ; load the eeprom address
    movwf EEADR ; store it in the eeprom register
    movf eedata, w ; load the eeprom data
    movwf EEDATA ; store it in the eeprom register
    movlw 0x55 ; load the first unlock sequence
    movwf EECON2 ; store it in the eeprom register
    movlw 0xAA ; load the second unlock sequence
    movwf EECON2 ; store it in the eeprom register
    bsf EECON1, WR ; start the write operation
    btfsc EECON1, WR ; wait until the write is done
    goto $-1
    bcf EECON1, WREN ; disable the write operation
    bcf PIR1, EEIF ; clear the write done flag
    bcf EECON1, WR ; clear the write bit
    bcf EECON1, WRERR ; clear the write error bit
    bsf INTCON, GIE ; enable the global interrupt
    bcf STATUS, RP0 ; select bank 0
    incf eeadr, f ; increment the eeprom address
    andlw EEPROM_MASK ; mask it
    movwf EEADR ; store it in the eeprom register
    movf counter2, w ; get the next byte of the counter
    andlw 0x0F ; mask the lower nibble
    movwf eedata ; store it in the eeprom data variable
    swapf counter2, w ; swap the nibbles of the counter
    andlw 0x0F ; mask the lower nibble
    iorwf eedata, f ; or it with the eeprom data
    bsf STATUS, RP0 ; select bank 1
    bcf EECON1, EEPGD ; select the data memory
    bcf EECON1, WREN ; disable the write operation
    bcf INTCON, GIE ; disable the global interrupt
    bcf EECON1, WR ; clear the write bit
    bcf EECON1, WRERR ; clear the write error bit
    bcf PIR1, EEIF ; clear the write done flag
    bsf EECON1, WREN ; enable the write operation
    movf eeadr, w ; load the eeprom address
    movwf EEADR ; store it in the eeprom register
    movf eedata, w ; load the eeprom data
    movwf EEDATA ; store it in the eeprom register
    movlw 0x55 ; load the first unlock sequence
    movwf EECON2 ; store it in the eeprom register
    movlw 0xAA ; load the second unlock sequence
    movwf EECON2 ; store it in the eeprom register
    bsf EECON1, WR ; start the write operation
    btfsc EECON1, WR ; wait until the write is done
    goto $-1
    bcf EECON1, WREN ; disable the write operation
    bcf PIR1, EEIF ; clear the write done flag
    bcf EECON1, WR ; clear the write bit
    bcf EECON1, WRERR ; clear the write error bit
    bsf INTCON, GIE ; enable the global interrupt
    bcf STATUS, RP0 ; select bank 0
    incf eeadr, f ; increment the eeprom address
    andlw EEPROM_MASK ; mask it
    movwf EEADR ; store it in the eeprom register
    movf counter3, w ; get the most significant byte of the counter
    andlw 0x0F ; mask the lower nibble
    movwf eedata ; store it in the eeprom data variable
    swapf counter3, w ; swap the nibbles of the counter
    andlw 0x0F ; mask the lower nibble
    iorwf eedata, f ; or it with the eeprom data
    bsf STATUS, RP0 ; select bank 1
        ; store the most significant byte of the counter in the eeprom
    bcf EECON1, EEPGD ; select the data memory
    bcf EECON1, WREN ; disable the write operation
    bcf INTCON, GIE ; disable the global interrupt
    bcf EECON1, WR ; clear the write bit
    bcf EECON1, WRERR ; clear the write error bit
    bcf PIR1, EEIF ; clear the write done flag
    bsf EECON1, WREN ; enable the write operation
    movf eeadr, w ; load the eeprom address
    movwf EEADR ; store it in the eeprom register
    movf eedata, w ; load the eeprom data
    movwf EEDATA ; store it in the eeprom register
    movlw 0x55 ; load the first unlock sequence
    movwf EECON2 ; store it in the eeprom register
    movlw 0xAA ; load the second unlock sequence
    movwf EECON2 ; store it in the eeprom register
    bsf EECON1, WR ; start the write operation
    btfsc EECON1, WR ; wait until the write is done
    goto $-1
    bcf EECON1, WREN ; disable the write operation
    bcf PIR1, EEIF ; clear the write done flag
    bcf EECON1, WR ; clear the write bit
    bcf EECON1, WRERR ; clear the write error bit
    bsf INTCON, GIE ; enable the global interrupt
    bcf STATUS, RP0 ; select bank 0

; emit the current cycle count using serial output
emit_counter
    movlw DIVIDER ; load the divider for the timer0
    movwf TMR0 ; store it in the timer0
    movlw 0x20 ; load the bit count
    movwf bitcnt ; store it in the bit count variable
    bcf GPIO, 0 ; clear the output pin
    btfss INTCON, T0IF ; wait until the timer0 overflows
    goto $-1
    bcf INTCON, T0IF ; clear the timer0 flag
    movlw DIVIDER ; reload the divider for the timer0
    movwf TMR0 ; store it in the timer0
    bsf GPIO, 0 ; set the output pin
    btfss INTCON, T0IF ; wait until the timer0 overflows
    goto $-1
    bcf INTCON, T0IF ; clear the timer0 flag
    movlw DIVIDER ; reload the divider for the timer0
    movwf TMR0 ; store it in the timer0
emit_bit
    rrf counter3, f ; rotate the counter right
    rrf counter2, f
    rrf counter1, f
    rrf counter0, f
    btfsc STATUS, C ; check the carry flag
    bsf GPIO, 0 ; set the output pin if 1
    btfss STATUS, C ; skip if 1
    bcf GPIO, 0 ; clear the output pin if 0
    btfss INTCON, T0IF ; wait until the timer0 overflows
    goto $-1
    bcf INTCON, T0IF ; clear the timer0 flag
    movlw DIVIDER ; reload the divider for the timer0
    movwf TMR0 ; store it in the timer0
    decfsz bitcnt, f ; decrement the bit count
    goto emit_bit ; repeat until all bits are sent
    bsf GPIO, 0 ; set the output pin
    goto emit_counter ; loop forever
    end ; end of the program
    
