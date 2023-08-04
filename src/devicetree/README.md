# COMET68k DeviceTree
The files in this directory are (or create) a devicetree blob which describes the hardware layout of the COMET68k.

Please note: At present this is a work in progress!

To compile the devicetree you can use an open source tool called `dtc` (Device Tree Compiler). On a Mac this can be installed via `brew install dtc`. For other OSes, you'll need to refer to your specific utilities to locate and install `dtc`.

Once installed, compilation is as simple as `dtc COMET68k.dts > COMER68k.dtb`.

The devicetree blob (`.dtb`) can be merged into ROM images to allow code to adapt itself to different memory layouts and peripheral addresses.
