# Hardware 

The printed circuit board was designed using KiCad.  The [schematic](./schematic.pdf) and [Gerber files](./gerbers.zip) are the final version.  See [`firmware/`](../firmware) for how to program the microcontroller.

## Parts List

| Part | Qty | Reference Designators |
|------|-----|-------|
| [0.1uF 50V Capacitor](https://www.mouser.com/ProductDetail/594-K104M15X7RF53L2) | 2 | C1, C2 |
| [10uF 100V Capacitor](https://www.mouser.com/ProductDetail/661-E-101L100MF11D) | 1 | C3 |
| [T1-3/4 Green LED](https://www.mouser.com/ProductDetail/606-4304H5) | 3 | D1, D2, D3 |
| [10-pin 2x5 1.27mm Male Shrouded Header SMT](https://www.ebay.com/itm/171560426679) | 1 | J1 |
| [1x6 2.54mm Male Header](https://www.mouser.com/ProductDetail/649-1012937890604BLF) | 1 | J2 |
| [1x2 2.54mm Male Header](https://www.mouser.com/ProductDetail/649-1012937890201BLF) | 3 | J3, J4, J5 |
| [2N3904 Transistor](https://www.mouser.com/ProductDetail/512-2N3904BU) | 1 | Q1 |
| [10K 1/4W Resistor](https://www.mouser.com/ProductDetail/603-MFR-25FTE52-10K) | 3 | R1, R2, R3 |
| [1K 1/4W Resistor](https://www.mouser.com/ProductDetail/603-MFR-25FTF52-1K) | 1 | R7 |
| [150 ohm 1/4W Resistor](https://www.mouser.com/ProductDetail/603-MFR-25FTE52-150R) | 3 | R4, R5, R6 |
| [MX-Compatible Keyboard Switch](https://www.amazon.com/dp/B07K7J38SB) | 3 | SW1, SW2, SW3 |
| [CD4066BM](https://www.mouser.com/ProductDetail/595-CD4066BM96) | 1 | U1 |
| [ATtiny414-SSN](https://www.mouser.com/ProductDetail/579-ATTINY414-SSN) | 1 | U2 |

Note: The ATtiny214, ATtiny414, and ATtiny814 are all supported.  Although any of these can be used, the ATtiny414 and ATtiny814 are preferred because they have twice the EEPROM space (128 bytes) as the ATtiny214 (64 bytes).  The firmware uses a wear-leveling algorithm that spreads writes across the EEPROM locations, so the ATtiny414 and ATtiny814 should last twice as long as the ATtiny214.
