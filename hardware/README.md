# Hardware 

The MXLock circuit consists of two main components: an ATtiny214/414/814 microcontroller and a 4066 analog switch.  The momentary key switches are connected directly to the microcontroller.  The 4066 is connected to the computer's keyboard matrix.

Up to four locking keys can be simulated, `LOCK0` through `LOCK3`: 

 - `LOCK0` can also reset the computer if held down.  The computer must have active-low reset input (`/RESET`) like on the 6502.
 - `LOCK1` and `LOCK2` have no special characteristics.
 - `LOCK3` has the limitation that its LED that can't be turned of programmatically unless its 4066 contact is also turned off.  If fewer than four keys are required, choose the others instead.

The design files are in KiCad format.  A [PDF schematic](./schematic.pdf) and [Gerber files](./gerbers.zip) are also available.  The PCB is only for demonstration and testing purposes; the MXLock circuit is intended to be integrated onto a keyboard.

See [`firmware/`](../firmware) for how to program the microcontroller.

## Parts List

The demo board uses the following components:

| Part | Qty | Reference Designators |
|------|-----|-------|
| [0.1uF 50V Capacitor](https://www.mouser.com/ProductDetail/594-K104M15X7RF53L2) | 2 | C1, C2 |
| [10uF 100V Capacitor](https://www.mouser.com/ProductDetail/661-E-101L100MF11D) | 1 | C3 |
| [T1-3/4 Green LED](https://www.mouser.com/ProductDetail/606-4304H5) | 4 | D1, D2, D3, D4 |
| [1x2 2.54mm Male Header](https://www.mouser.com/ProductDetail/649-1012937890201BLF) | 4 | J1, J2, J3, J4 |
| [10-pin 2x5 1.27mm Male Shrouded Header SMT](https://www.ebay.com/itm/171560426679) | 1 | J6 |
| [1x4 2.54mm Male Header](https://www.mouser.com/ProductDetail/649-1012937890401BLF) | 1 | J5 |
| [2N3904 Transistor](https://www.mouser.com/ProductDetail/512-2N3904BU) | 1 | Q1 |
| [330 ohm 1/4W Resistor](https://www.mouser.com/ProductDetail/603-MFR-25FTE52-330R) | 3 | R1, R2, R3, R4 |
| [1K 1/4W Resistor](https://www.mouser.com/ProductDetail/603-MFR-25FTF52-1K) | 1 | R5, R6 |
| [MX-Compatible Keyboard Switch](https://www.amazon.com/dp/B07K7J38SB) | 4 | SW1, SW2, SW3, SW4 |
| [ATtiny414-SSN](https://www.mouser.com/ProductDetail/579-ATTINY414-SSN) | 1 | U1 |
| [CD4066BM](https://www.mouser.com/ProductDetail/595-CD4066BM96) | 1 | U2 |

Notes: 

 - The ATtiny214, ATtiny414, and ATtiny814 are all supported.  Although any of these can be used, the ATtiny414 and ATtiny814 are preferred because they have twice the EEPROM space (128 bytes) as the ATtiny214 (64 bytes).  The firmware uses a wear-leveling algorithm that spreads writes across the EEPROM locations, so the ATtiny414 and ATtiny814 should last twice as long as the ATtiny214.

 - Each LED should draw no more than 12 mA or else damage to the ATtiny may occur.  If another type of LED is substituted, adjust the resistor values accordingly.
