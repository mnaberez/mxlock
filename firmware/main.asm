;ATtiny214
;1  VCC
;2  PA4 out EXTRAOUT to 4066 (0=off, 1=on)
;3  PA5 out SLOUT 
;4  PA6 out CAPSOUT 
;5  PA7 out 4080OUT 
;6  PB3 out /CBMRESET (0=/CBMRESET=open, 1=/CBMRESET=low)
;7  PB2 in 4080KEY (0=down, 1=up)
;8  PB1 in CAPSKEY 
;9  PB0 in SLKEY 
;10 UPDI
;11 PA1 out SLLED (0=on, 1=off)
;12 PA2 out CAPSLED
;13 PA3 out 4080LED 
;14 GND

    ;Definitions file "tn214def.asm"
    ;will be included first by the Makefile.

    .area code (abs)
    .list (me)

    .org PROGMEM_START/2  ;/2 because PROGMEM_START constant is byte-addressed
                          ;but ASAVR treats program space as word-addressed.
    rjmp reset

    ;All interrupt vectors jump to fatal error (interrupts are not used)
    .rept INT_VECTORS_SIZE - 1
    rjmp fatal
    .endm

    ;Code starts at first location after vectors
    .assume . - ((PROGMEM_START/2) + INT_VECTORS_SIZE)

reset:
    ;Clear RAM
    ldi ZL, <INTERNAL_SRAM_START
    ldi ZH, >INTERNAL_SRAM_START
    clr r16
1$: st Z, r16                 ;Store 0 at Z
    ld r16, Z+                ;Read it back, increment Z
    tst r16                   ;Did it read back as 0?
    breq 2$                   ;Yes: continue clearing
    rjmp fatal                ;No: hardware failure, jump to fatal
2$: cpi ZL, <(INTERNAL_SRAM_END+1)
    brne 1$
    cpi ZH, >(INTERNAL_SRAM_END+1)
    brne 1$

    ;Initialize stack pointer
    ldi r16, <INTERNAL_SRAM_END
    out CPU_SPL, r16
    ldi r16, >INTERNAL_SRAM_END
    out CPU_SPH, r16

    rcall wdog_init
    rcall gpio_init

    ldi r19, 0

main_loop:
    wdr                       ;Keep watchdog happy
    rcall gpio_read_keys
    eor r19, r16
    mov r16, r19
    rcall gpio_set_leds
    rcall gpio_set_contacts
    rjmp main_loop

;Wait 1ms.  Destroy R16,R17
delay_1ms:
    ldi r16, 6
1$: ldi r17, 0xc5
2$: dec r17
    brne 2$
    dec r16
    brne 1$
    ret

;GPIO =======================================================================

;
;The GPIO routines abstract the I/O pins such that the same bit
;pattern is used for the key inputs, LED outputs, and 4066 outputs.
;The bit values use positive logic:
;
; - A bit of "0" means key up / LED off / 4066 contact open
; - A bit of "1" means key down / LED on / 4066 contact closed
;

;Read the key switch inputs and return them in R16
;0=key up, 1=key down
;
;R16:
;  Bit 3 = Always 0 (would be Extra key)
;  Bit 2 = 40/80 key 
;  Bit 1 = Caps Lock key
;  Bit 0 = Shift Lock key
;
gpio_read_keys:
    ;Read PORTB_IN and convert to R16 bits
    lds r16, PORTB_IN
    ldi r17, 1<<2 | 1<<1 | 1<<0
    and r16, r17
    eor r16, r17  ;PORTB_IN bits are inverted (0=key down)
    ret

;Set the 4066 contacts from the value in R16
;0=contact open, 1=contact closed
;
;R16:
;  Bit 3 = Extra contact
;  Bit 2 = 40/80 contact
;  Bit 1 = Caps Lock contact
;  Bit 0 = Shift Lock contact
;
gpio_set_contacts:
    push r16

    ;Convert R16 bits to PORTA_OUT bits
    lsl r16 
    lsl r16 
    lsl r16 
    lsl r16 
    lsl r16 
    andi r16, 1<<7 | 1<<6 | 1<<5 | 1<<4

    ;Set/clear bits in PORTA_OUT
    lds r17, PORTA_OUT
    andi r17, 0xff ^ (1<<7 | 1<<6 | 1<<5 | 1<<4)
    or r17, r16
    sts PORTA_OUT, r17

    pop r16
    ret

;Set the LEDs from the value in R16
;0=LED off, 1=LED on
;
;R16:
;  Bit 3 = Ignored (would be Extra LED)
;  Bit 2 = 40/80 LED
;  Bit 1 = Caps Lock LED
;  Bit 0 = Shift Lock LED
;
gpio_set_leds:
    push r16

    ;Convert R16 bits to PORTA_OUT bits
    lsl r16
    ldi r17, 1<<3 | 1<<2 | 1<<1
    and r16, r17
    eor r16, r17  ;PORTA_OUT bits are inverted (0=LED on)

    ;Set/clear bits in PORTA_OUT
    lds r17, PORTA_OUT
    andi r17, 0xff ^ (1<<3 | 1<<2 | 1<<1)    
    or r17, r16
    sts PORTA_OUT, r17

    pop r16
    ret

;Pull the /CBMRESET pin to GND, resetting the CBM computer
;
gpio_cbmreset_on:
    ldi r16, 1<<3           ;PB3
    sts PORTB_OUTSET, r16   ;set PB3=1 which pulls /CBMRESET low
    ret

;Open the /CBMRESET pin, allowing the CBM computer to run
;
gpio_cbmreset_off:
    ldi r16, 1<<3           ;PB3
    sts PORTB_OUTCLR, r16   ;set PB3=0 which makes /CBMRESET open
    ret

;Set initial GPIO directions and states
;
; - LED pins as outputs; LEDs not lit
; - 4066 pins as outputs; contacts open
; - /CBMRESET pin as output; /CBMRESET=open
;
gpio_init:
    ;Key Inputs
    ldi r16, 1<<2 | 1<<1 | 1<<0     ;PB2, PB1, PB0
    sts PORTB_DIRCLR, r16           ;Set pins as input

    ;4066 Outputs
    ldi r16, 1<<7 | 1<<6 | 1<<5 | 1<<4  ;PA7, PA6, PA5, PA4
    sts PORTA_OUTCLR, r16           ;Set 4066s initially off (0=off)
    sts PORTA_DIRSET, r16           ;Set pins as outputs

    ;LED Outputs
    ldi r16, 1<<3 | 1<<2 | 1<<1     ;PA3, PA2, PA1
    sts PORTA_OUTSET, r16           ;Sets LEDs initially off (1=off)
    sts PORTA_DIRSET, r16           ;Set pins as outputs

    ;/CBMRESET Output
    ldi r16, 1<<3                   ;PB3
    sts PORTA_OUTCLR, r16           ;Set /CBMRESET initially high (0=high)
    sts PORTB_DIRSET, r16           ;Set PB3 as output
    ret

;WATCHDOG ===================================================================

;Ensure the watchdog was started by the fuses and reset the timer.
;The WDR instruction must be executed at least once every 4 seconds
;or the watchdog will reset the system.
wdog_init:
    ;Ensure watchdog period has been configured
    lds r16, WDT_CTRLA
    andi r16, WDT_PERIOD_gm
    cpi r16, WDT_PERIOD_4KCLK_gc      ;Watchdog period set by the fuses?
    breq 1$                           ;Yes: continue
    rjmp fatal                        ;No: bad fuses, jump to fatal

    ;Ensure watchdog is locked so it can't be stopped
1$: lds r16, WDT_STATUS
    sbrs r16, WDT_LOCK_bp             ;Skip fatal if locked
    rjmp fatal

    wdr                               ;Reset watchdog timer
    ret

;END OF CODE ================================================================

    ;Fill all unused program words with a nop sled that ends with
    ;a software reset in case the program counter somehow gets here.
    .nval filler_start,.
    .rept ((PROGMEM_END/2) - filler_start - fatal_size)
    nop
    .endm

;Fatal error causes software reset
fatal:
    cli                       ;Disable interrupts
    ldi r16, CPU_CCP_IOREG_gc
    ldi r17, RSTCTRL_SWRE_bm
    out CPU_CCP, r16          ;Unlock Protected I/O Registers
    sts RSTCTRL_SWRR, r17     ;Software Reset

fatal_size = . - fatal

;Last program word (last 2 bytes) will be the CRC16 added by the Makefile
crc16:
    .assume . - (PROGMEM_END/2)
