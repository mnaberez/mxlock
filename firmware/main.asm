;ATtiny214/ATtiny414/ATtiny814
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

    ;Definitions file will be included first by the Makefile.

    .area code (abs)
    .list (me)
    .32bit

;RAM
current_keys     = SRAM_START+0 ;Current state of keys
previous_keys    = SRAM_START+1 ;State of keys last time around the main loop
shift_down_ticks = SRAM_START+2 ;Number of ticks Shift Lock has been held down

;Constants
TICK_MS         = 20    ;Milliseconds in one tick
RESET_MS        = 50    ;Milliseconds to hold /CBMRESET low to reset
SHIFT_DOWN_MS   = 1500  ;Milliseconds of Shift Lock held down to cause reset

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
    rjmp jmp_fatal
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
    jmp fatal                 ;No: hardware failure, jump to fatal
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

    rcall task_keys             ;Check keys and update 4066 contacts
    rcall task_reset            ;Reset computer if Shift Lock is held down
    rcall task_eeprom           ;Store 4066 contacts in EEPROM
    rcall task_leds             ;Update LEDs from 4066 contacts

    lds r16, current_keys       
    sts previous_keys, r16      ;Save keys for next time around

    rjmp main_loop              ;Loop forever

;TASKS ======================================================================

;
;The main loop calls all of these tasks each time around.  There is a 
;delay of 1 tick between each iteration of the main loop, which these
;tasks can use for timing.
;

;Check each key and toggle its 4066 contact if it was just pushed down.
;
task_keys:
    ldi r18, 1<<KEY_40_80       ;First key to check (highest bit position)

1$: lds r16, current_keys
    and r16, r18                ;Leave only key of interest from current
    breq 2$                     ;Branch if key is not down

    lds r17, previous_keys
    and r17, r18                ;Leave only key of interest from previous
    eor r17, r16                ;Compare with current state of key
    breq 2$                     ;Branch if key has not changed

    ;Key has changed and is down
    rcall gpio_read_contacts
    eor r16, r18                ;Toggle the 4066 contact
    rcall gpio_write_contacts

2$: lsr r18                     ;Rotate right to next key
    brne 1$                     ;Loop until all keys are checked

    ret

;Check for reset request and reset CBM if needed
;If Shift Lock is held down long enough, reset the CBM, restore the
;previous Shift Lock state, and block until Shift Lock is released.
;
task_reset:
    lds r16, current_keys
    lds r17, shift_down_ticks
    sbrs r16, KEY_SHIFT_LOCK    ;Skip next if Shift Lock is down
    clr r17
    cpi r17, #0xff              ;Cap tick counter (do not wrap to 0)
    breq 1$
    inc r17
1$: sts shift_down_ticks, r17

    cpi r17, SHIFT_DOWN_MS/TICK_MS ;Held down long enough to reset?
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

;Update 4066 contact state in EEPROM if needed
;
task_eeprom:
    lds r16, current_keys
    or r16, r16
    brne 1$                     ;Do nothing if any key is down

    rcall eeprom_read_contacts
    mov r17, r16
    rcall gpio_read_contacts
    cp r16, r17
    breq 1$                     ;Do nothing if no change

    ;Contacts do not match the EEPROM, time to write to the EEPROM

    mov r17, r16                ;Save contacts in R17

    clr r16                     ;Turn off LEDs so that if power is lost,
    rcall gpio_write_leds       ;  they take no residual power from EEPROM

    mov r16, r17                ;Recall contacts 
    rcall eeprom_write_contacts 

1$: ret

;Update the LEDs from the 4066 contacts
;This task should be called last in the main loop because other
;tasks may temporarily change the state of the LEDs.
;
task_leds:
    rcall gpio_read_contacts    
    rjmp gpio_write_leds        

;UTILITIES ==================================================================

;Read the keys with gpio_read_keys and debounce for one tick
;
read_debounced_keys:
    push r18
    push r17

1$: ldi r18, TICK_MS          ;Debounce time
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

;Work around RJMP range limitation
;
jmp_fatal:
    jmp fatal

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

;
;The EEPROM is used to store the state of the 4066 contacts, which is only
;1 byte.  However, there are 64 bytes available in the EEPROM on the 
;ATtiny214 and 128 bytes on the ATTiny414/814.  Since each EEPROM location
;can only be erased about 100K times, the entire area is used to store the 
;1 byte using this wear-leveling algorithm:
;
; - To write the 4066 contacts byte, the lowest location in the EEPROM that
;   is erased (0xFF) will receive the byte using the write-only (no erase)
;   command.  If no location contains 0xFF, the entire EEPROM will be erased
;   back to 0xFF and the first location will receive the byte.
;
; - To read the 4066 contacts byte from the EEPROM, the byte in the highest
;   location that does not contain 0xFF will be returned.
;
;The above algorithm will hopefully allow the 4066 contacts to change
;64 * 100K (6.4 million) times on the ATtiny214 or 128 * 100K (12.8 million)
;times on the ATtiny414/814 before the EEPROM wears out.
;

;Read 4066 contact state from the EEPROM into R16
;Destroys Y
;
;Find the highest location in the EEPROM that is
;not erased (0xFF) and return its value.  If the
;entire EEPROM is empty, return 0 (all contacts off).
;
eeprom_read_contacts:
    ldi YL, <(EEPROM_END+1)
    ldi YH, >(EEPROM_END+1)
1$: ld r16, -Y                          ;Load byte currently in EEPROM
    cpi r16, #0xff                      ;Erased (0xFF)?
    brne 2$                             ;  Yes: branch to return this byte
    cpi YL, #<EEPROM_START
    brne 1$
    cpi YH, #>EEPROM_START
    brne 1$
    ldi r16, 0                          ;EEPROM is empty; return 0 (all off)
2$: ret

;Store R16 as the 4066 contact state in the EEPROM
;Destroys R16, R17, Y
;
;Find the lowest location in the EEPROM that is erased (0xFF) and
;write the value there.  If there is no unerased location, erase
;the entire EEPROM and write the value in the first location.
;
eeprom_write_contacts:
    rcall eeprom_wait_ready

    ldi YL, <EEPROM_START
    ldi YH, >EEPROM_START

1$: ld r17, Y+                          ;Load byte currently in EEPROM
    cpi r17, #0xff                      ;Erased (0xFF)?
    breq 2$                             ;  Yes: branch to write byte here

    cpi YL, <(EEPROM_END+1)
    brne 1$
    cpi YH, >(EEPROM_END+1)
    brne 1$

    ;No unerased byte; erase EEPROM and reset pointer
    push r16                            ;Save 4066 contacts
    ldi r16, NVMCTRL_CMD_EEERASE_gc     ;Erase EEPROM command
    rcall eeprom_send_cmd
    pop r16                             ;Recall 4066 contacts
    ldi YL, <(EEPROM_START+1)
    ldi YH, <(EEPROM_START+1)

2$: st -Y, r16                          ;Store 4066 contacts in buffer                 
    ldi r16, NVMCTRL_CMD_PAGEWRITE_gc   ;Write-only command

    ;Fall through

;Send the NVMCTRL command in R16
;Destroys R17
;
eeprom_send_cmd:
    ldi r17, CPU_CCP_SPM_gc
    out CPU_CCP, r17                    ;Unlock NVMCTRL_CTRLA
    sts NVMCTRL_CTRLA, r16              ;Perform EEPROM command in R16

    ;Fall through

;Block until the EEPROM is ready
;Destroys R17
;
eeprom_wait_ready:
    lds r17, NVMCTRL_STATUS
    sbrc r17, NVMCTRL_EEBUSY_bp         ;Skip next if EEPROM is ready
    rjmp eeprom_wait_ready
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
    jmp fatal                         ;No: bad fuses, jump to fatal

    ;Ensure watchdog is locked so it can't be stopped
1$: lds r16, WDT_STATUS
    sbrs r16, WDT_LOCK_bp             ;Skip fatal if locked
    jmp fatal

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
