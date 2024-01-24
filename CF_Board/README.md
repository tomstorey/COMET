# Design Progress Document
This document outlines the progress for the following design:

**Name:** Compact Flash board

**Revision:** 1

**Date:** December 2023

## Status
| Item | Progress |
|--|--|
| Schematic | Complete |
| PCB layout | In progress |
| PCB build | Not started |
| Functional testing | Prototyped, see notes |
| Further revision | Unknown |

The overall status for this design is: **Mothballed**

## Notes
A simpler version of this board has been prototyped, but the design was since expanded.

Further functional testing is required once PCBs have been produced.

This design was intended to use the IORDY signal to stretch/time bus cycles, but the IORDY signal does not work in such a way as to be useful for this purpose. A new design is pending which will provide flexibility to adjust bus cycle timing to suit slower and faster cards.
