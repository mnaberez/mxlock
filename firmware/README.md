# Firmware

The firmware is written in AVR assembly language.  It can be built for the ATtiny214, ATtiny414, and ATtiny814.

## Build

Building requires:

- ASAVR (part of the [ASxxxx](https://shop-pdp.net/ashtml/) cross-assemblers package)
- [SRecord](http://srecord.sourceforge.net/) version 1.64 or later
- GNU [Make](https://www.gnu.org/software/make/)
- A Unix-like operating system (e.g. Linux, macOS)

Run `make` to produce Intel Hex files for the flash, fuses, and EEPROM:

    make MCU=t414

If `MCU=` is not given, the default target is `t414` (ATtiny414).  Valid targets are `MCU=t214`, `MCU=t414`, and `MCU=t814`.  It may be helpful to read the [`Makefile`](./Makefile) and the [GitHub workflow](../.github/workflows/main.yml).

## Flash

MXLock has a dedicated header for connecting to an [Atmel-ICE](https://www.microchip.com/en-us/development-tool/ATATMEL-ICE).  It also has pins on its 2.54mm header that can be used to connect to a different UPDI programmer.  In both cases, [AVRDUDE 7.2 or later](https://github.com/avrdudes/avrdude) is used.

### Atmel-ICE

Connect the Atmel-ICE to the dedicated header on the MXLock board.  Also connect a 5VDC power supply to the 5V and GND pins on the 2.54mm header.  Install the Atmel-ICE drivers and then run `make program`, specifying `MCU=` if needed.

### SerialUPDI

A SerialUPDI programmer can also be used.  One can be made from an FTDI [TTL-232R-5V](https://www.mouser.com/ProductDetail/895-TTL-232R-5V) cable and a 1KΩ resistor.  Make the following connections to the MXLock board:

- FTDI RX → UPDI
- FTDI TX → 1KΩ resistor → UPDI
- FTDI GND → GND

A 5VDC power supply must also be connected to the MXLock board.  The 5V pin on the FTDI cable may be used as the power supply.

Since macOS and most Linux distributions ship with built-in FTDI drivers, drivers are not normally required.  Run `make program` and use `ISPFLAGS=` to set the SerialUPDI options for AVRDUDE:

    make program MCU=t414 ISPFLAGS='-c serialupdi -P /dev/cu.usbserial-FTABCDEF'

The above command will flash an ATTiny414 using SerialUPDI on port `/dev/cu.usbserial-FTABCDEF`.

## References

- [ATtiny214/414/814 Datasheet](https://web.archive.org/web/20231029180615if_/https://ww1.microchip.com/downloads/en/DeviceDoc/40001912A.pdf)

- [AVR Instruction Set Manual](https://web.archive.org/web/20211122051203if_/http://ww1.microchip.com/downloads/en/devicedoc/atmel-0856-avr-instruction-set-manual.pdf)
