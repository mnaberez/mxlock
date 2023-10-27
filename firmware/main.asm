;ATtiny214
;1  VCC
;2  PA4 out EXTRAOUT to 4066 (0=off, 1=on)
;3  PA5 out SLOUT 
;4  PA6 out CAPSOUT 
;5  PA7 out 4080OUT 
;6  PB3 NC
;7  PB2 in 4080KEY (0=down, 1=up)
;8  PB1 in CAPSKEY 
;9  PB0 in SLKEY 
;10 UPDI
;11 PA1 out SLLED (0=on, 1=off)
;12 PA2 out CAPSLED
;13 PA3 out 4080LED 
;14 GND

;shift_lock  SLKEY PB0 = 1
;            SLOUT PA5 = 32
;            SLLED PA1 = 2
;
;caps_lock   CAPSKEY PB1 = 2
;            CAPSOUT PA6 = 64
;            CAPSLED PA2 = 4
;
;forty_lock  4080KEY PB2 = 4
;            4080OUT PA7 = 64
;            4080LED PA3 = 8


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

main_loop:
    wdr                       ;Keep watchdog happy
    rcall read_keys
    rcall set_leds
    rcall set_contacts
    rjmp main_loop

;Set up GPIO directions
gpio_init:
    ;Button Inputs
    ldi r16, 1<<2 | 1<<1 | 1<<0     ;PB2, PB1, PB0
    sts PORTB_DIRCLR, r16           ;set pins as input

    ;4066 Outputs
    ldi r16, 1<<7 | 1<<6 | 1<<5 | 1<<4  ;PA7, PA6, PA5, PA4
    sts PORTA_OUTCLR, r16               ;set 4066s initially off (0=off)
    sts PORTA_DIRSET, r16               ;set pins as outputs

    ;LED Outputs
    ldi r16, 1<<3 | 1<<2 | 1<<1     ;PA3, PA2, PA1
    sts PORTA_OUTSET, r16           ;sets LEDs initially off (1=off)
    sts PORTA_DIRSET, r16           ;set pins as outputs
    ret


;Returns key status in R16:
;
;   Bit 2 = 4080 key (0=up, 1=down)
;   Bit 1 = caps key
;   Bit 0 = shift lock key
;
read_keys:
    ldi r17, 1<<2 | 1<<1 | 1<<0
    lds r16, PORTB_IN
    eor r16, r17
    ret

;Sets LEDs from R16
;
;   Bit 2 = 4080 LED (0=off, 1=on)
;   Bit 1 = caps lock LED
;   Bit 0 = shift lock LED
;
set_leds:
    push r16
    lsl r16
    ldi r17, 1<<3 | 1<<2 | 1<<1
    and r16, r17
    eor r16, r17

    lds r17, PORTA_OUT
    andi r17, 0xff ^ (1<<3 | 1<<2 | 1<<1)    
    or r17, r16
    sts PORTA_OUT, r17
    pop r16
    ret

;Sets 4066 contacts from R16
;
;   Bit 2 = 4080 contact (0=off, 1=on)
;   Bit 1 = caps lock contact
;   Bit 0 = shift lock contact
;
set_contacts:
    push r16
    lsl r16 
    lsl r16 
    lsl r16 
    lsl r16 
    lsl r16 
    andi r16, 1<<7 | 1<<6 | 1<<5 | 1<<4

    lds r17, PORTA_OUT
    andi r17, 0xff ^ (1<<7 | 1<<6 | 1<<5 | 1<<4)
    or r17, r16
    sts PORTA_OUT, r17
    pop r16
    ret


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

;Wait 1ms.  Destroy R16,R17
delay_1ms:
    ldi r16, 6
1$: ldi r17, 0xc5
2$: dec r17
    brne 2$
    dec r16
    brne 1$
    ret

;End of code

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
