# COMETbus Development Tool - Configuration
## Summary
This document covers the steps required to configure a newly built Dev Tool. Configuration requires two utilitiy applications, one supplied by Microchip and the other by FTDI, to apply appropriate default settings that will be recalled by the MCP2221A and FT232R chips on the Dev Tool board. Finally, a I2C EEPROM must be programmed with an included file that contains settings that will be loaded by the USB hub.

**Note:** this configuration process requires access to a Windows computer to run the above mentioned utilities. At the time of writing I havent yet documented or developed a method to perform the configuration from a *nix based OS, but it can certainly be done.

** IMPORTANT:** Follow this configuration guide in the order of the sections below. Do not connect the board to your computer until instructed to do so.

## USB Hub Configuration EEPROM
The USB hub is configured via strapping resistors to load its configuration from an I2C EEPROM. The I2C interface of the USB hub is limited in its capability, so the EEPROM should be 256 bytes in size, and must require only a single address byte to access its contents. The USB hub starts at address 0 and reads 256 bytes of data into its internal memory to apply its run-time configuration.

The reference EEPROM part number is: 24C02C-I/P

A file included in this repo called `USB_hub_EEPROM.bin` contains all of the required settings for the USB hub on a Dev Tool. This configuration file should be used, as it contains settings that will reverse the D+ and D- signals on some of the USB ports as required by the PCB layout.

Use an EEPROM programming tool to write this file to an EEPROM chip, and install it on the Dev Tool board in site U3.

Once this is complete, the Dev Tool board can be connected to your PC to continue with the remainder of the configuration process.

## FT232R Cofiguration
Two FT232R's on the Dev Tool represent Ports A and B. These two chips require some settings to be changed using the "FT Prog" tool, which can be downloaded directly from FTDI.

As there are two chips on the board, a simple process is used to first identify which chip corresponds to Port A and which to Port B so that the correct product string can be applied to each chip. The product string allows each port to be easily identified once enumerated in an OS that supports name based ports.

Additionally, each chip has an LED connected to its `CBUS0` pin. The factory default function for this pin is `TXLED#` which pulsates when data is transmitted via the serial port, however, the most ideal use for this LED is for both TX and RX traffic indicator.

Use the following steps to identify the two chips:

1. Open the FT Prog utility, go to the DEVICES menu, and click "Scan and Parse". The Device Tree on the left hand side of FT Prog must list two devices. If possible, disconnect all other FTDI devices from the PC to help identify only the two FTDIs on the Dev Tool board.
2. From the tree of Device 0, expand the "Hardware Specific" node and click "IO Controls".
3. In the middle of the window, for the C0 property, select "CLK6" from the dropdown list
4. From the DEVICES menu, click Program. Ensure that only Device 0 is selected. Click the Program button and verify that the status indicates that programming was successful. If so, click "Cycle Ports".
5. You should now see the LED for either Port A or Port B illuminated. Close the Program Devices window.
6. Modify the C0 property once again, this time selecting "TX&RXLED#". This will be the final configuration for this setting.
7. From the Device Tree, click on "USB String Descriptors" for Device 0. In the Manufacturer string enter `COMETbus Development Tool`. In the Product Descriptor string enter either `Port A` or `Port B` depending on which LED has illuminated.
8. Ensure "Serial Number Enabled" is checked. If the Serial Number field is blank, check the "Auto Generate Serial No" option.
9. From the Device Tree, click on "USB Config Descriptor" for Device 0. Make sure the "Self Powered" option is selected.
10. Steps 6-9 may be repeated for Device 1, using the opposide Product Descriptor string to Device 0.
11. From the DEVICES menu, click Program. This time, ensure that both devices are selected. Click the Program button and verify that the status indicates that programming was successful. If so, click "Cycle Ports".

Both FTDI chips are now configured.

## MCP2221A Configuration
The MCP2221A represents Port C. Like the FTDI chips, this chip requires some settings to be configured and stored in the device for recall on startup. These settings can be changed using the "MCP2221 Utility" which can be downloaded directly from Microchip.

Use of the `devtool.py` script heavily revolves around identifying the MCP2221A on the Dev Tool board by its serial number, therefore this configuration process is quite crucial to perform - arguably moreso than the FTDI chips.

1. Open the MCP2221 Utility, it should automatically recognise the MCP2221A if the board is connected to your PC and display its current non-volatile configuration. If possible, disconnect all other MCP2221A devices from the PC to help identify only the one on the Dev Tool board.
2. Under "Power Configuration", change Power Source to "Self-powered"
3. In the "Strings" section, change Descriptor to `Port C`, and Manufacturer to `COMETbus Dev Tool`. Ensure that "Enumerate with serial number" is checked.
4. Under "GP Pin Configuration" set GP1 to `2 (ADC1)`, GP2 to `0 (GPIO` with `Output` direction and `Logical High (1)` Pin Value, and ensure that GP3 is set to `1 (LED_I2C)`.
5. Click "Configure Device" at the bottom of the window to save settings to the devices built-in flash memory, and check that the Status Output on the right indicates that the operation was successful.

The MCP2221A is now configured.

**Note:** The MCP2221A has some (at time of writing) undocumented errata regarding the ADC Vref configuration which prevents them from being correctly recalled when the device starts up. Leave these settings unchanged - they will be configured by `devtool.py` during operation.
