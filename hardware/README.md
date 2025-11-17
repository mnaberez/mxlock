# Hardware 

The MXLock circuit consists of two main components: an ATtiny214/414/814 microcontroller and a 4066 quad analog switch.  The momentary key switches are connected directly to the microcontroller.  The 4066 is connected to the computer's keyboard matrix.

Up to four locking keys can be simulated, `LOCK0` through `LOCK3`: 

 - `LOCK0` can also reset the computer if held down.  If the circuit on the demo board is used, the computer must have an active-low reset input (`/RESET`) like on the 6502.
 - `LOCK1` and `LOCK2` have no special characteristics.
 - `LOCK3` has the limitation that its LED that can't be turned off programmatically unless its 4066 contact is also turned off.  LOCK3 may also prevent the ATtiny from entering shutdown mode (see note below).   If fewer than four keys are required, choose the others instead.

The design files are in KiCad format.  A [PDF schematic](./schematic.pdf) and [Gerber files](./gerbers.zip) are also available.  The PCB is only for demonstration and testing purposes; the MXLock circuit is intended to be integrated onto a keyboard.

See [`firmware/`](../firmware) for how to program the microcontroller.

## Power Consumption

The ATtiny is put into full shutdown mode (CPU and internal oscillator stopped) between keypressess.  At 5.0 VDC, with no key being pressed down and the 4066 contacts all in the open state, the [Joulescope JS220](https://www.joulescope.com) measures the demo board as drawing about 140 nA / 0.140 μA.

The demo board consumes about 8.5 mA total when one of the contacts is closed and its LED is lit.  This power draw is dominated by the LED.  The board consumes about 8.5 * 4 = 34 mA when all four contacts are closed and their LEDs are lit.  Different LEDs and current limiting resistors can be used to reduce power.  The LEDs can also be omitted for the lowest possible current draw.

`LOCK3` should be avoided if power consumption is a concern as it may prevent the ATtiny from shutting down.  Pressing `LOCK3` a few times may put the ATtiny into a state where it draws about 1.5 mA between keypresses even though all contacts and LEDs are off.  In this state, pressing `LOCK3` a few more times may return the current draw to normal (~ 140 nA).  The input pin for `LOCK3` is shared with the UPDI interface.  Presumably, activity on this pin puts the chip's internal UPDI circuitry into a state where it draws more power.

Notes:

- If a UPDI programmer is connected, the power consumption of the demo board increases.  Disconnect UPDI before measuring current.

- If different LEDs or current limiting resistors are used, each LED must draw no more than 12 mA or else damage to the ATtiny may occur.

## EEPROM Life

The internal EEPROM of the ATtiny is used to restore the state of the keys after power is lost.  The EEPROM is updated whenever a key changes state.  The firmware uses a wear-leveling algorithm to spread writes across the EEPROM locations for maximum life.

Although the ATtiny214 is supported, it should be avoided if longevity is a concern:

The ATtiny414 and ATtiny814 are preferred because they have twice the EEPROM space (128 bytes) as the ATtiny214 (64 bytes).  The ATtiny214 should withstand 6.4 million key
changes, the ATtiny414 and ATtiny814 should withstand twice that at 12.8 million.  

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
