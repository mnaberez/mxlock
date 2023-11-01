
;Definitions file "tn214def.asm"
;will be included first by the Makefile.

.area eeprom (abs, dseg)
.org 0
.rept EEPROM_SIZE
.byte 0xFF
.endm
