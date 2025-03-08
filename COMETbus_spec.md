# COMETbus Specification
The COMETbus specification is intended to be a subset of the VMEbus specification. While COMETbus shares the same physical backplane as VMEbus, and largely the same signal arrangement, some changes have been introduced with the intention of achieving a simpler bus implementation more suitable for homebrew 68k systems.

This document will describe the most significant differences to VMEbus.

The current release version of this specification is v1.0, dated 2025/03/08.

## Document Conventions  
The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119).

Signal names which are suffixed by a forward slash (/) and which are level sensitive are true or asserted when they are at a low logic level.

Signal names which are suffixed by a forward slash (/) and which are edge sensitive initiate their actions on the high to low transition.

## Introduction
COMETbus grew out of my COMET68k homebrew computer project. I'd had a VMEbus backplane sitting around at home for quite some time, and intended to one day build a VME compatible system. But as an initial project I decided to settle for something a bit simpler, and more akin to a traditional asynchronous CPU bus, re-using signals where possible for the same or like functions.

A core goal of COMETbus is simplicity: signals and capabilities SHALL be constrained to those which function across a VME J1 backplane. As such, and while data and address busses on-board a CPU card MAY be any width at the designers choosing, COMETbus intends to only support 16 bit transfers across the backplane within the 16 megabyte address space afforded by the address bus of a VMEbus J1 backplane.

It was decided to maintain a subset of arbitration functionality within COMETbus to allow for DMA operations to and from more advanced peripheral cards.

Data transfers are restricted to a maximum of 16 bits at a time, and complex "Address Modifier" schemes are omitted in favour of a simpler upper and lower data strobe scheme as found on a 68000/68010 CPU. For the 68020 and above with dynamic bus sizing, a translation layer MUST be provided by logic on the CPU card. CPU cards which do not have a native 16-bit on-board data bus MUST have appropriate mechanisms to support 16-bit data transfers as required by a peripheral card. Transfers of long values are supported, but will be effected as two word transfers, and are not signalled to peripheral cards.

# Signal Definitions
By and large, most VMEbus signals are carried across to COMETbus. The following table outlines all of the signals of the VMEbus J1 connector, and if/how they have been modified.

| Pin | VMEbus | COMETbus | Notes |
|-|-|-|-|
|  | A23..1 | A23..1 |  |
|  | ACFAIL/ |  |  |
|  | AM0 | FC0 | Equivalent CPU signal |
|  | AM1 | FC1 | Equivalent CPU signal |
|  | AM2 | FC2 | Equivalent CPU signal |
|  | AM3 |  |  |
|  | AM4 |  |  |
|  | AM5 |  |  |
|  | AS/ | AS/ |  |
|  | BBSY/ |  |  |
|  | BCLR/ |  |  |
|  | BERR/ | BERR/ |  |
|  | BG0IN/ | BG0IN/ | SHOULD be bridged to BG0OUT/ if unused |
|  | BG0OUT/ | BG0OUT/ | SHOULD be bridged to BG0IN/ if unused |
|  | BG1IN/ | BG1IN/ | SHOULD be bridged to BG1OUT/ if unused |
|  | BG1OUT/ | BG1OUT/ | SHOULD be bridged to BG1IN/ if unused |
|  | BG2IN/ |  | MUST be bridged to BG2OUT/ |
|  | BG2OUT/ |  | MUST be bridged to BG2IN/ |
|  | BG3IN/ |  | MUST be bridged to BG3OUT/ |
|  | BG3OUT/ |  | MUST be bridged to BG3IN/ |
|  | BR0/ | BR0/ | Highest priority in COMETbus |
|  | BR1/ | BR1/ | Lowest priority in COMETbus |
|  | BR2/ |  |  |
|  | BR3/ |  |  |
|  | D15..0 | D15..0 |  |
|  | DS0/ | LDS/ | Equivalent CPU signal |
|  | DS1/ | UDS/ | Equivalent CPU signal |
|  | DTACK/ | DTACK/ |  |
|  | IACK/ | AUTOVEC/ | Allows an interrupter to autovector instead of supplying a vector |
|  | IACKIN/ | IACKIN/ | SHOULD be bridged to IACKOUT/ if unused |
|  | IACKOUT/ | IACKOUT/ | SHOULD be bridged to IACKIN/ if unused |
|  | IRQx/ | IRQx/ |  |
|  | LWORD/ |  |  |
|  | SERCLK |  |  |
|  | SERDAT |  |  |
|  | SYSCLK | SYSCLK |  |
|  | SYSFAIL/ |  |  |
|  | SYSRESET/ | SYSRESET/ |  |
|  | WRITE/ | WRITE/ |  |

All signals which are undefined within the COMETbus column MUST NOT be used for any purpose to ensure compatibility with this specification as it continues to evolve.

VMEbus backplanes include features to daisy chain certain signals across the length of the backplane, including through unoccupied slots. These features include jumpers or headers which must be bridged manually, logic gates to propagate signals, or sockets which close built-in contacts once a card is removed from it. Designers of cards for COMETbus systems SHOULD observe the recommendations made above to bridge certain signals when they are unused.

## Bus Arbitration
COMETbus includes the ability for another device to become the bus master. Such other devices may include DMA controllers inside advanced peripherals. Multiple CPU cards are not intended to be supported in a COMETbus system. Arbitration is achieved through the use of a two-wire request/grant scheme.

The current specification does not define a mechanism to evict a bus master should a higher priority request be generated elsewhere. Therefore, a bus master SHALL be able to consider itself the sole keeper of the bus until it has completed its current operation.

Since the COMETbus specification places no restrictions on how long a bus master may hold the bus, designers are encouraged to think conscientiously about how they interact with the system and what performance implications may be introduced by these interactions.

### Bus request 0 and 1
Bus Request BR0/ and BR1/ and corresponding Bus Grant BGxIN/ and BGxOUT/ signals are specified for use within a COMETbus system. Their function is as per the VMEbus specification.

COMETbus does not specify any requirements for fairness in arbitration schemes, nor does it restrict how bus request 0 or 1 are prioritised against, or mixed with, arbitration sources on-board to the arbiter. The designer is free to choose their desired mix of arbitration sources.

Bus request 0 is considered to be the higher priority for arbitration requests received from the backplane, and the only constraint is that it SHOULD be granted ahead of bus request 1.

### Bus request 2 and 3
Bus Request BR2/ and BR3/ and corresponding Bus Grant BGxIN/ and BGxOUT/ signals are reserved in the current COMETbus specification.

## Interrupts and AUTOVEC/
### IRQx/
These signals retain their function as per the VMEbus specification.

### IACKIN/ and IACKOUT/
These signals retain their function as per the VMEbus specification.

### AUTOVEC/
VMEbus does not have any built-in mechanism to allow a peripheral to autovector an interrupt - all peripherals must supply a vector during interrupt acknowledge when they are the serviced interrupter.

To simplify interrupt handling in a COMETbus system, the IACK/ signal has been replaced with AUTOVEC/ which permits a peripheral to signal back to the CPU that it can autovector the currently serviced interrupt. The CPU card generates the IACK/ signal which it propagates via the IACKOUT/ to IACKIN/ daisy chain.

A peripheral must only ever assert the AUTOVEC/ signal when it is the currently serviced interrupter, which is resolved through the IACKIN/ to IACKOUT/ daisy chain and matching IRQ signalled via A3..1.
