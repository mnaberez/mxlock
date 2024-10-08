
;Definitions file will be included first by the Makefile.

.area fuses (abs, dseg)

;Watchdog Configuration
.org 0+FUSE_WDTCFG_offset
.byte 0

;BOD Configuration
.org 0+FUSE_BODCFG_offset
.byte 0

;Oscillator Configuration
.org 0+FUSE_OSCCFG_offset
.byte (0<<FUSE_OSCLOCK_bp) | FUSE_FREQSEL_16MHZ_gc

;Reserved fuse between OSCCFG and TCD0CFG should not be programmed

;TCD0 Configuration
.org 0+FUSE_TCD0CFG_offset
.byte (0<<FUSE_CMPDEN_bp) | (0<<FUSE_CMPCEN_bp) | (0<<FUSE_CMPBEN_bp) | (0<<FUSE_CMPAEN_bp) | (0<<FUSE_CMPD_bp) | (0<<FUSE_CMPC_bp) | (0<<FUSE_CMPB_bp) | (0<<FUSE_CMPA_bp)

;System Configuration 0
.org 0+FUSE_SYSCFG0_offset
.byte FUSE_RSTPINCFG_UPDI_gc | (0<<FUSE_EESAVE_bp)

;System Configuration 1
.org 0+FUSE_SYSCFG1_offset
.byte FUSE_SUT_64MS_gc

;Application Code Section End
.org 0+FUSE_APPEND_offset
.byte 0

;Boot Section End
.org 0+FUSE_BOOTEND_offset
.byte 0
