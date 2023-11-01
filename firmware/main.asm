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

;RAM
current_keys     = SRAM_START+0 ;Current state of keys
previous_keys    = SRAM_START+1 ;State of keys last time around the main loop
shift_down_ticks = SRAM_START+2 ;Number of ticks Shift Lock has been held down

;Constants
TICK_MS         = 20    ;Number of milliseconds in one tick
RESET_MS        = 50    ;Number of milliseconds to hold /CBMRESET low to reset

;Constants for bit positions used with GPIO functions
KEY_EXTRA       = 3     ;Extra (4066 contact only)
KEY_40_80       = 2     ;40/80 key / LED / 4066 contact
KEY_CAPS_LOCK   = 1     ;Caps Lock key / LED / 4066 contact
KEY_SHIFT_LOCK  = 0     ;Shift Lock key / LED / 4066 contact

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

    rcall eeprom_read_contacts  ;Read 4066 contacts saved in EEPROM
    rcall gpio_write_contacts   ;  and restore the 4066 to that state

    ldi r16, 0                  ;Initialize variables to defaults
    sts current_keys, r16
    sts previous_keys, r16
    sts shift_down_ticks, r16

main_loop:
    wdr                         ;Keep watchdog happy

    rcall read_debounced_keys   ;Read keys (delays 1 tick to debounce)
    sts current_keys, r16

    rcall task_caps_lock        ;Check Caps Lock, update 4066 contacts
    rcall task_40_80            ;  ... 40/80
    rcall task_shift_lock       ;  ... Shift Lock
    rcall task_shift_lock_reset ;Reset computer if Shift Lock is held down
    rcall task_leds             ;Update LEDs

    lds r16, current_keys       
    sts previous_keys, r16      ;Save keys for next time around
    rjmp main_loop              ;Loop forever

;TASKS ======================================================================

;
;The main loop calls all of these tasks each time around.  There is a 
;delay of 1 tick between each iteration of the main loop, which these
;tasks can use for timing.
;

;Check for Caps Lock keypress
;Update its 4066 contact on transition from not pressed to pressed
;
task_caps_lock:
    lds r16, current_keys
    lds r17, previous_keys
    eor r17, r16
    sbrc r17, KEY_CAPS_LOCK     ;Skip next if Caps Lock has not changed
    sbrs r16, KEY_CAPS_LOCK     ;Skip next if Caps Lock is down
    ret

    ;Caps lock has changed and is down
    rcall gpio_read_contacts
    ldi r17, 1<<KEY_CAPS_LOCK
    eor r16, r17                ;Toggle Caps Lock contact
    rjmp gpio_write_contacts

;Check for 40/80 keypress
;Update its 4066 contact on transition from not pressed to pressed
;
task_40_80:
    lds r16, current_keys
    lds r17, previous_keys
    eor r17, r16
    sbrc r17, KEY_40_80         ;Skip next if 40/80 has not changed
    sbrs r16, KEY_40_80         ;Skip next if 40/80 is down
    ret

    ;40/80 has changed and is down
    rcall gpio_read_contacts
    ldi r17, 1<<KEY_40_80
    eor r16, r17                ;Toggle 40/80 contact
    rjmp gpio_write_contacts

;Check for Shift Lock keypress
;Update its 4066 contact on transition from not pressed to pressed
;
task_shift_lock:
    lds r16, current_keys
    lds r17, previous_keys
    eor r17, r16
    sbrc r17, KEY_SHIFT_LOCK     ;Skip next if Shift Lock has not changed
    sbrs r16, KEY_SHIFT_LOCK     ;Skip next if Shift Lock is down
    ret

    ;Shift lock has changed and is down
    rcall gpio_read_contacts
    ldi r17, 1<<KEY_SHIFT_LOCK
    eor r16, r17                 ;Toggle Shift Lock contact
    rjmp gpio_write_contacts

;Check if Shift Lock is being held down
;If held down long enough, the CBM is reset, the previous Shift Lock
;state is restored, and the task blocks until the key is released.
;
task_shift_lock_reset:
    lds r16, current_keys
    lds r17, shift_down_ticks
    sbrs r16, KEY_SHIFT_LOCK    ;Skip next if Shift Key is down
    clr r17
    cpi r17, #0xff              ;Cap tick counter (do not wrap to 0)
    breq 1$
    inc r17
1$: sts shift_down_ticks, r17

    cpi r17, #1500/TICK_MS      ;Held down for >=1500 milliseconds?
    brlo 3$

    ;Shift Lock held down long enough; it's time to reset the CBM

    ;Reset count for next time
    clr r16
    sts shift_down_ticks, r16

    ;Restore Shift Lock to its state before being pressed down
    rcall gpio_read_contacts
    ldi r17, 1<<KEY_SHIFT_LOCK
    eor r16, r17
    rcall gpio_write_contacts
    rcall gpio_write_leds

    ;Pulse /CBMRESET low
    rcall gpio_cbmreset_on
    ldi r16, RESET_MS
    rcall wait_n_ms
    rcall gpio_cbmreset_off

    ;Wait for Shift Lock to be released (prevents multiple resets)
2$: rcall read_debounced_keys
    sts current_keys, r16
    wdr
    sbrc r16, KEY_SHIFT_LOCK
    rjmp 2$

3$: ret

;Update the LEDs from the 4066 contacts
;
task_leds:
  rcall gpio_read_contacts    ;Read 4066 contact states
  rjmp gpio_write_leds        ;  and update LEDs from them

;UTILITIES ==================================================================

;Read the keys with gpio_read_keys and debounce for one tick
;
read_debounced_keys:
    push r18
    push r17

1$: ldi r18, TICK_MS+1        ;Debounce time
2$: rcall wait_1_ms
    rcall gpio_read_keys      ;Returns keys in R16
    cp r16, r17               ;Same as last keys?
    mov r17, r16              
    brne 1$                   ;  No: start all over

    dec r18                    
    brne 2$                   ;Loop for debounce time

    pop r17
    pop r18
    ret

;Busy wait for N milliseconds in R16
;
wait_n_ms:
    rcall wait_1_ms
    dec r16
    brne wait_n_ms
    ret

;Busy wait for 1 millisecond
;
wait_1_ms:
    push r16
    push r17
    ldi r16, 0x05
1$: ldi r17, 0xde
2$: dec r17
    brne 2$
    dec r16
    brne 1$
    pop r17
    pop r16
    ret

;GPIO =======================================================================

;
;The GPIO routines abstract the I/O pins such that the bit
;positions in the KEY_* constants are used for all the 
;routines (the key inputs, LED outputs, and 4066 contacts).
;
;The bit values use positive logic:
;
; - A bit of "0" means key up / LED off / 4066 contact open
; - A bit of "1" means key down / LED on / 4066 contact closed
;

;Read all the key switch inputs and return them in R16
;0=key up, 1=key down
;
gpio_read_keys:
    push r17
    lds r17, PORTB_IN

    ;Convert PORTB_OUT bits to R16 bits
    clr r16
    sbrs r17, 2                 ;PB2 clear
    ori r16, 1<<KEY_40_80       ;  sets 40/80 bit
    sbrs r17, 1                 ;PB1 clear
    ori r16, 1<<KEY_CAPS_LOCK   ;  sets Caps Lock bit
    sbrs r17, 0                 ;PB0 clear
    ori r16, 1<<KEY_SHIFT_LOCK  ;  sets Shift Lock bit
    pop r17
    ret

;Write all the 4066 contacts from the value in R16
;0=contact open, 1=contact closed
;
gpio_write_contacts:
    push r16
    push r17

    ;Convert R16 bits to PORTA_OUT bits
    clr r17
    sbrc r16, KEY_SHIFT_LOCK    
    ori r17, 1<<5               ;Shift Lock bit set sets PA5
    sbrc r16, KEY_CAPS_LOCK     
    ori r17, 1<<6               ;Caps Lock bit set sets PA6
    sbrc r16, KEY_40_80         
    ori r17, 1<<7               ;40/80 bit set sets PA7
    sbrc r16, KEY_EXTRA         
    ori r17, 1<<4               ;Extra bit set sets PA4

    ;Set/clear bits in PORTA_OUT
    lds r16, PORTA_OUT
    andi r16, 0xff ^ (1<<7 | 1<<6 | 1<<5 | 1<<4)
    or r16, r17
    sts PORTA_OUT, r16

    pop r17
    pop r16
    ret

;Read the state of all the 4066 contacts into R16
;0=contact open, 1=contact closed
;
gpio_read_contacts:
    push r17
    lds r17, PORTA_OUT

    ;Convert PORTA_OUT bits to R16 bits
    clr r16
    sbrc r17, 5                 
    ori r16, 1<<KEY_SHIFT_LOCK  ;PA5 set sets Shift Lock bit
    sbrc r17, 6                 
    ori r16, 1<<KEY_CAPS_LOCK   ;PA6 set sets Caps Lock bit
    sbrc r17, 7                 
    ori r16, 1<<KEY_40_80       ;PA7 set sets 40/80 bit
    sbrc R17, 4                 
    ori r16, 1<<KEY_EXTRA       ;PA4 set sets Extra bit

    pop r17
    ret

;Write all the LED outputs from the value in R16
;0=LED off, 1=LED on
;
gpio_write_leds:
    push r16 
    push r17

    ;Convert R16 bits to PORTA_OUT bits
    clr r17
    sbrs r16, KEY_SHIFT_LOCK    
    ori r17, 1<<1               ;Shift Lock bit clear sets PA1
    sbrs r16, KEY_CAPS_LOCK     
    ori r17, 1<<2               ;Caps Lock bit clear sets PA2
    sbrs r16, KEY_40_80         
    ori r17, 1<<3               ;40/80 bit clear sets PA3

    ;Set/clear bits in PORTA_OUT
    lds r16, PORTA_OUT
    andi r16, 0xff ^ (1<<3 | 1<<2 | 1<<1)    
    or r16, r17
    sts PORTA_OUT, r16

    pop r17
    pop r16
    ret

;Read the state of all the LED outputs into R16
;0=LED off, 1=LED on
;
gpio_read_leds:
    push r17
    lds r17, PORTA_OUT

    ;Convert PORTA_OUT bits to R16
    clr r16
    sbrs r17, 3                 
    ori r16, 1<<KEY_40_80       ;PA3 clear sets 40/80 bit
    sbrs r17, 2                 
    ori r16, 1<<KEY_CAPS_LOCK   ;PA2 clear sets Caps Lock bit
    sbrs r17, 1                 
    ori r16, 1<<KEY_SHIFT_LOCK  ;PA1 clear sets Shift Lock bit

    pop r17
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
    sts PORTB_OUTCLR, r16           ;Set /CBMRESET initially high (0=high)
    sts PORTB_DIRSET, r16           ;Set PB3 as output
    ret

;EEPROM =====================================================================

eeprom_read_contacts:
    lds r16, EEPROM_START
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
