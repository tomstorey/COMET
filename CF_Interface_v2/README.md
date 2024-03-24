# Design Progress Document
This document outlines the progress for the following design:

**Name:** Compact Flash Interface v2

**Revision:** 2

**Date:** March 2024

## Status
| Item | Progress |
|--|--|
| Schematic | Complete |
| PCB layout | Complete |
| PLD logic | Complete |
| PCB build | Complete |
| Functional testing | Complete |
| Further revision | None |

The overall status for this design is: **Stable**

## Revision History

### Revision 1
Initial release.

### Revision 2
Two issues were discovered with rev 1, and fixed in rev 2:

* A minor issue whereby I hadnt excluded copper from the edges of the board that slide in to the guides in a subrack. Not likely to cause any issues, but it was against my intention.
* A major issue whereby I had wired the read buffer of the control/status register in backwards such that when trying to read the register it would output in to the signals that were trying to be read, thus you could never read back the status register. No other functionality was affected, so rev 1 was used for CPLD logic development and most functional testing.

In addition, to facilitate easier CF card removal, a notch was added to the PCB outline to allow better grip of the card.
