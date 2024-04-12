# About
COMET is my take on a highly integrated, small form factor Motorola 68000 based computer featuring "COM" ports and an "ET"hernet controller.

Physically, a COMET based system is based around a standard VMEbus J1 backplane, but with a simplified interface specification for easier system building, which I call COMETbus. COMETbus removes a lot of the multi-CPU arbitration type stuff and relaxes or removes some other requirements to become more like a simple asynchronous system bus. A document outlining the differences is a work in progress.

VMEbus backplanes are typically used in industrial applications and therefore tend to come with an industrial price tag. This repo contains two backplane designs that you can build yourself, potentially much cheaper if nothing else is available. Please note that VMEbus backplanes will require a power supply capable of at least 1A current, plus any additional current per installed expansion board. It's not for the faint of heart!

Expansion boards are targeted to be 160x100mm in size to slot in to a standard subrack.

# Disclaimer
COMET and its associated peripherals are considered a work in progress. There may be errors, omissions, and problems yet undiscovered. Use at your own risk. :-)

# License
I am not a lawyer, so I will make this simple.

This is a personal project, so I make this repository and all of its contents available exclusively for your personal use, should you wish to build it yourself, or take inspiration from it for your own personal use projects.

If you make use of any part of this repository, please ensure to retain all notices and provide attribution.

This license does not override that of any works which I have relied on.
