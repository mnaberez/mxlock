
;Definitions file "tn214def.asm"
;will be included first by the Makefile.

.area eeprom (abs, dseg)

.org 0
.byte 0 ;indicates no keys latched

.nval current_address,.
.rept (EEPROM_SIZE - current_address)
.byte 0xFF
.endm
