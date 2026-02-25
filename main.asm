/*
* Laboratorio3.asm
*
* Creado: 18/02/2026
* Autor : Jose Flores
* Descripcion: 
* - Pre-Lab: Contador binario de 4 bits con interrupciones Pin Change.
* - Lab: Contador de segundos hexadecimal de 4 bits en display de 7 segs.
* - Post-Lab: Contador de 0 a 59 segundos usando Timer0 y multiplexación.
*/

/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"

.cseg
// Tabla de Vectores de Interrupción 
.org 0x0000
    RJMP SETUP

.org 0x0008             ; PCINT
    RJMP ISR_PCINT1     ; interrupcion de botones (Puerto C)

.org 0x0020
    RJMP ISR_TIMER0     ; interrupcion por overflow de Timer0 

// Tabla de 7 segmentos (catodo comun)
Table7seg:
    .db 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0X07, 0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71

/****************************************/
// Configuracion MCU
SETUP:
    // Configuración de la pila
    LDI R16, LOW(RAMEND)
    OUT SPL, R16
    LDI R16, HIGH(RAMEND)
    OUT SPH, R16

    // I/O
    ; Puerto B - PB0-PB3 (Contador binario), PB4-PB5 (Transistores para MUX)
    LDI R16, 0x3F       ; 0b0011_1111 
    OUT DDRB, R16

    // Puerto D - Display de 7 segmentos
    LDI R16, 0xFF		; 0b1111_1111
    OUT DDRD, R16

    // Puerto C - Botones
    CBI DDRC, PC0
    CBI DDRC, PC1
    SBI PORTC, PC0      ; habilitar pull-up
    SBI PORTC, PC1

    // Interrupciones PCINT
    LDI R16, (1 << PCIE1)                  ; habilitar grupo PCINT1 (Puerto C)
    STS PCICR, R16
    LDI R16, (1 << PCINT8) | (1 << PCINT9) ; habilitar PC0 y PC1
    STS PCMSK1, R16

    // Configuracion de Timer0
    // Prescaler 1024 - Interrupción 10ms
    LDI R16, 100
    OUT TCNT0, R16
    LDI R16, 0x05              ; prescaler 1024
    OUT TCCR0B, R16
    LDI R16, (1 << TOIE0)      ; habilitar interrupción TMR0
    STS TIMSK0, R16

    // Inicializar variables
    CLR R19     ; unidades
	CLR R20     ; contador leds   
    CLR R21     ; milisegundos
    CLR R22     ; decenas
    CLR R23     ; bandera de mux
    

    SEI         ; habilitar interrupciones globales
    
/****************************************/
// Loop Infinito
MAIN_LOOP:
    RJMP MAIN_LOOP ; main loop vacio

/****************************************/
// Interrupt routines

// ISR de los botones (Puerto C)
ISR_PCINT1:
    PUSH R16
    IN R16, SREG
    PUSH R16

    SBIS PINC, PC0        ; si PC0 es 1 (no presionado), se salta la siguiente instrucción      
    INC R20
    
    SBIS PINC, PC1             
    DEC R20

    ANDI R20, 0x0F        ; mascara de 4 bits (0 a 15)

    POP R16
    OUT SREG, R16
    POP R16
    RETI

// ISR del Timer0 (10 ms)
ISR_TIMER0:
    PUSH R16
    IN R16, SREG
    PUSH R16
    PUSH ZL               ; guardamos el puntero Z
    PUSH ZH

//  Recargar Timer
    LDI R16, 100               
    OUT TCNT0, R16

//  Multiplexacion
    INC R23
    SBRS R23, 0           ; revisa el bit 0. Si es 1, salta a decenas
    RJMP unidades

decenas:
// enciende transistor PB4
    MOV R16, R20
    ORI R16, (1 << PB4)   
    OUT PORTB, R16
    
// cargar valor de las decenas (R22)
    MOV R16, R22
    RJMP dispup

unidades:
// enciende transistor PB5
    MOV R16, R20
    ORI R16, (1 << PB5)   
    OUT PORTB, R16
    
// Cargar valor de las unidades (R19)
    MOV R16, R19

dispup:
// Obtener el código de 7 segmentos de la tabla
    LDI ZH, HIGH(Table7seg << 1)
    LDI ZL, LOW(Table7seg << 1)
    ADD ZL, R16
    CLR R16
    ADC ZH, R16
    LPM R16, Z                  
    OUT PORTD, R16        ; mostrar en el display            

//  Reloj
    INC R21                   ; acumula 10ms
    CPI R21, 100              ; revisa si se llego a 1000 ms (1s)
    BRNE tmrend

    CLR R21                   ; reinicia ms
    INC R19                   ; incrementar unidades
    CPI R19, 10               ; compara con 10 unidades (una decena)
    BRNE tmrend

    CLR R19                   ; reinicia unidades
    INC R22                   ; incrementa decenas
    CPI R22, 6                ; compara con 6 decenas (60 segundos)
    BRNE tmrend

    CLR R22                   ; reinicia decenas y regresa a 0

tmrend:
    POP ZH
    POP ZL
    POP R16
    OUT SREG, R16
    POP R16
    RETI