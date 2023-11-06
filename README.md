# MXLock

[![Photo](./hardware/photos/board.jpg)](./hardware/photos/board.jpg)

This microcontroller circuit is used to simulate latching keys on Steve Gray's [Cherry MX replacement keyboards](http://6502.org/users/sjgray/projects/mxkeyboards/) for 8-bit Commodore computers.

Many Commmodore keyboards have a mechanically latching key for `SHIFT LOCK`.  The Commodore 128 has three latching keys: `SHIFT LOCK`, `CAPS LOCK`, and `40/80`.  This is a problem for Cherry MX projects because mechanically latching MX keys are difficult to find and expensive.  

MXLock solves this problem by allowing regular momentary MX keys to be used for up to 3 latching keys.  It simulates the latching action so users can preserve their 40/80 mode or EFFICIENTLY YELL at others online again, just like they could with their original Commodore keyboards.

Features:

 - Simulates up to 3 latching keys using an [ATtiny214/414/814](https://web.archive.org/web/20231029180615if_/https://ww1.microchip.com/downloads/en/DeviceDoc/40001912A.pdf) and a [4066](https://web.archive.org/web/20231029180910if_/https://www.ti.com/lit/ds/symlink/cd4066b-mil.pdf)
 - Shows the on/off state of each key with LEDs
 - Remembers the latch states between power cycles (useful for `40/80`)
 - Resets the computer by pulling `/RESET` low if `SHIFT LOCK` is held down

## Hardware

The hardware in this repository is only used for development.  The circuit is intended to be integrated onto the keyboard's circuit board.  For an example of a keyboard using the circuit, see Steve's [C128SX keyboard](http://6502.org/users/sjgray/projects/mxkeyboards/).

Although MXLock was designed for use on Steve's keyboards, it can be used on other keyboards as well, as long as the key contacts can be closed using a 4066.  See [`hardware/`](./hardware/) for the schematic and parts list.

## Firmware

The firmware is written in AVR assembly language and is assembled using [ASxxxx](https://shop-pdp.net/ashtml/).  It can be flashed with the [Atmel-ICE](https://www.microchip.com/en-us/development-tool/atatmel-ice) or another UPDI programmer.  See [`firmware/`](./firmware/) for the source code and instructions.

## Author

[Mike Naberezny](https://github.com/mnaberez)
