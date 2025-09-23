# COMETbus Development Tool
## Summary
The COMETbus Development Tool ("Dev Tool") is intended to aid with development activities in a COMETbus system ("target system"). The primary intention is to provide a scriptable interface to reset the target system during the build process, in order to return to the bootloader to accept a new code download.

The Dev Tool is a compound USB device incorporating a four port USB High-Speed hub to which three on-board devices are attached:

* 2x FTDI FT232R USB-serial converters with RS-232 line drivers
* 1x Microchip MCP2221A USB-serial converter and I2C bridge with NXP PCA9535 GPIO expander

The 4th port of the USB hub is presented on a USB Type-A socket to allow an external device to be connected, such as a USB flash drive or other programming tool.

The two FTDI USB-serial converters are intended to connect to the serial ports on the COMET68k CPU card to eliminate the need for individual USB-serial converter cables, while the MCP2221A and PCA9535 provide GPIO for various system control functions. This reduces the number of cables connected between the host and target system to one.

Note: there are no peripherals on this board that are accessible from the target system.

### System control functions
The MCP2221A provides a USB-I2C bridge allowing a host-side script or application to read and write GPIOs of the PCA9535 GPIO expander. The COMETbus Dev Tool provides the following control functions via this arrangement:

* System reset
* Backplane power switching
* Interrupt generation with either auto-vectored or vectored interrupts on all 7 IRQ levels

A host-side companion script (written in Python) contained in this repository provides an easy interface to use this functionality and incorporate it into Makefiles.

The system reset function allows the system to be reset during development activities, returning to a bootloader and enabling a new version of code to be downloaded and run.

Backplane power switching is intended to provide a means to power cycle a system should it be necessary. This requires a special switchable power backplane (which has not yet been developed at the time of writing), and powering the Dev Tool from the standby 5V power rail of the VME backplane (because it is not bus powered).

Interrupt generation is intended to provide a simple interface to allow interrupt handling code and other related functions to be tested. Both vectored interrupts and auto-vectored interrupts are possible.

## Design Progress
**Revision:** 2
**Date:** September 2025

## Status
| Item | Progress |
|--|--|
| Schematic | Complete |
| PCB layout | Complete |
| PLD logic | Complete |
| PCB build | Not started |
| Functional testing | Not started |
| Further revision | None |

The overall status for this design is: **Stable**

## Notes
* This design is considered stable even though the PCB build and functional testing have not been completed. Revision 2 is based on fixes that have been implemented on revision 1 boards, and is therefore considered functionally equivalent.
* The PCB has been designed to be produced by aisler.net on their 4 layer board offering. If you intend to use another manufacturer, please check the specifications of the USB diff pairs with them, and adjust as required to maintain correct impedance.

## Revision History

### Revision 1
Initial release.

### Revision 2
Two issues were discovered with rev 1, and fixed in rev 2:

* Confusion with the USB2514B datasheet meant the logic for the "PC" LED was reversed, this was fixed by adding a transistor to invert the polarity of the signal
* 8P8C connectors were too far inboard, making it more difficult to disconnect cables from them

Other minor changes were made to improve functionality based on testing of rev 1, including:

* IN USE LED moved from the GPIO expander to be directly connected to the MCP2221A so that it is disabled on reset, giving a positive visual indication of whether the Dev Tool has been initialised and is ready for use
* The two FTDI chips and the MCP2221A will now be held in reset when the USB hub is in standby mode (e.g. if the upstream cable is disconnected)
