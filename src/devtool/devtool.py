from enum import IntEnum
import argparse
import struct
import os
import time
import usb.core


VERSION = 20250923

# I2C address of the PCA9535 GPIO expander connected to the MCP2221A
PCA9535_I2C_ADDR = 0x20

# The name of the environment variable that holds the serial number of the Dev Tool to use
DEV_TOOL_SN_VAR = "COMET_DEV_TOOL_SN"

# Set to True to display the amount of time the operation took to execute
SHOW_TIME = False

class BitMasks(IntEnum):
    IPL_POS = 0
    IPL_MASK = 0x0007 << IPL_POS

    AUTOVEC_POS = 3
    AUTOVEC_MASK = 0x0001 << AUTOVEC_POS

    ACKD_POS = 4
    ACKD_MASK = 0x0001 << ACKD_POS

    POWER_EN_POS = 5
    POWER_EN_MASK = 0x0001 << POWER_EN_POS

    BUSRESET_POS = 6
    BUSRESET_MASK = 0x0001 << BUSRESET_POS

    SYSRESET_POS = 7
    SYSRESET_MASK = 0x0001 << SYSRESET_POS

    VECTOR_POS = 8
    VECTOR_MASK = 0x00FF << VECTOR_POS


class MCP2221AError(Exception):
    pass


class MCP2221ATimeout(MCP2221AError):
    pass


class PCA9535Error(Exception):
    pass


def dev_tool_list():
    # Show a list of all MCP2221As that are enumerated
    mcp2221a_list = []

    for dev in usb.core.find(find_all=True):
        if dev.idVendor == 0x04D8 and dev.idProduct == 0x00DD:
            mcp2221a_list.append(
                {
                    "dev": dev,
                    "bus": dev.bus,
                    "address": dev.address,
                    "mfg": dev.manufacturer,
                    "product": dev.product,
                    "serial": dev.serial_number
                }
            )
    
    print(f"{len(mcp2221a_list)} MCP2221A(s) enumerated:\n")
    print(" #   Bus   Address   Manufacturer                     Product                          Serial")
    print("--   ---   -------   ------------------------------   ------------------------------   ----------------")

    for i, dev in enumerate(mcp2221a_list, 1):
        bus = dev["bus"]
        addr = dev["address"]
        mfg = dev["mfg"]
        prod = dev["product"]
        serial = dev["serial"]

        if serial is None:
            serial = "(None)"

        print(f"{i:2}   {bus:>3}   {addr:>7}   {mfg:30}   {prod:30}   {serial:16}")

    print()
    print(
        f"Copy the serial number and place it in an environment variable called {DEV_TOOL_SN_VAR}. Future calls to "
        f"devtool.py will then use this specific Dev Tool instance for all operations.\n"
    )

    sn = os.getenv(DEV_TOOL_SN_VAR)

    if sn is not None:
        print("Current environment variable:\n")
        print(f"{DEV_TOOL_SN_VAR}=\"{sn}\"\n")
    
""" Get a Dev Tool instance by its serial number.

Returns 2 values: OUT endpoint, IN endpoint
"""
def get_devtool_by_serial(sn):
    dt = None

    # Find the Dev Tool instance
    for dev in usb.core.find(find_all=True):
        if dev.idVendor == 0x04D8 and dev.idProduct == 0x00DD:
            if dev.serial_number == sn:
                dt = dev

                break

    if dt is None:
        # Didnt find a device
        return None, None

    # Now get the endpoints
    hid_interface = None
    out_ep = None
    in_ep = None

    for config in dt.configurations():
        for interface in config.interfaces():
            if interface.bInterfaceClass == 0x3: # HID
                hid_interface = interface.bInterfaceNumber

                if interface.bNumEndpoints == 2:
                    for endpoint in interface.endpoints():
                        if endpoint.bEndpointAddress & usb.util.ENDPOINT_IN:
                            in_ep = endpoint
                        else:
                            out_ep = endpoint
                    
                    break
                else:
                    dt = None

                    break
        
        if out_ep is not None and in_ep is not None:
            break

    if dt is None:
        # Didnt find a device
        return None, None

    # Detach kernel driver if necessary
    if dt.is_kernel_driver_active(hid_interface):
        dt.detach_kernel_driver(hid_interface)

    # All done, return endpoints
    return out_ep, in_ep


""" Transfers a TX buffer to a MCP2221A and return the received buffer.

In general, a response from the MCP2221A will have byte index 1 set to 0 if the command succeeded. These variables are
parameterised if they need to be changed on a per-call basis.

Returns 2 values: success (bool), list (received data)
Raises: MCP2221AError if TX fails
        MCP2221Timeout if RX times out
"""
def mcp2221a_transfer(out_ep, in_ep, tx_buf, success_index=1, success_value=0, errors=False):
    tx_len = out_ep.write(tx_buf)

    if tx_len != out_ep.wMaxPacketSize:
        raise MCP2221AError(f"Failed to send command packet (tx_len={tx_len})")

    try:
        rx_buf = in_ep.read(in_ep.wMaxPacketSize)
    except usb.core.USBTimeoutError:
        raise MCP2221ATimeout("USB communication timeout (RX)")

    if rx_buf[success_index] != success_value:
        if errors is True:
            print(f"ERROR: Command not successful ({rx_buf[success_index]:02x} != {success_value:02x})")

        return False, rx_buf

    return True, rx_buf

""" Set the state of GP2 (IN USE LED)

Other than the OUT and IN endpoints, it takes one additional parameter (boolean) which is the assertion state of the
LED output pin.

No value is returned
Raises: MCP2221AError if GP2 is not configured as a GPIO
"""
def mcp2221a_set_gp2(out_ep, in_ep, state, errors=False):
    # Prepare tx buffer
    tx_buf = [0] * 64
    tx_buf[0] = 0x50                # Set GPIO output values
    tx_buf[10] = 0x01               # Alter GP2 output
    tx_buf[11] = int(not state is True)

    _, rx_buf = mcp2221a_transfer(out_ep, in_ep, tx_buf, errors=errors)

    if rx_buf[10] == 0xEE:
        raise MCP2221AError("GP2 is not configured as a GPIO")

""" Get the state of GP2 (IN USE LED)

Returns: state (bool, representing the assertion state of the LED output pin)
Raises: MCP2221AError if GP2 is not configured as a GPIO
"""
def mcp2221a_get_gp2(out_ep, in_ep, errors=False):
    # Prepare tx buffer
    tx_buf = [0] * 64
    tx_buf[0] = 0x51                # Get GPIO values

    _, rx_buf = mcp2221a_transfer(out_ep, in_ep, tx_buf, errors=errors)

    # Return the state
    if rx_buf[6] == 0xEE:
        raise MCP2221AError("GP2 is not configured as a GPIO")
    
    return not bool(rx_buf[6])

""" Returns the voltage of the main 5V rail voltage in the target system

Returns: voltage (float)
"""
def mcp2221a_get_adc1(out_ep, in_ep, errors=False):
    # Prepare tx buffer
    tx_buf = [0] * 64
    tx_buf[0] = 0x10                # Status/set parameters

    _, rx_buf = mcp2221a_transfer(out_ep, in_ep, tx_buf, errors=errors)

    # Extract reading from receive buffer
    adc1 = struct.unpack("<H", rx_buf[50:52])[0]

    # Convert the ADC reading to a voltage and scale it up to the original voltage
    vin = ((adc1 / 1024) * 4.096) * 1.49

    return vin


""" Write commands and data to a PCA9535

No value is returned on success
Raises: PCA9535Error for a variety of error conditions
"""
def pca9535_transfer(out_ep, in_ep, tx_buf, errors=False):
    tries = 0

    while True:
        try:
            success, _ = mcp2221a_transfer(out_ep, in_ep, tx_buf, errors=errors)

            if success is False:
                # The datasheet lists only one particular reason for unsuccessful transfers, and that was because the
                # I2C engine was busy. Therefore retry the operation after a brief delay.
                #
                # Byte index 2 has an I2C engine state value that could be useful for improving error recoverability
                # with some more work.
                tries += 1

                if tries == 3:
                    raise PCA9535Error("Exhausted retries attempting to write to PCA9535")
                
                time.sleep(0.1)

                continue
            else:
                break
        except MCP2221ATimeout as e:
            raise PCA9535Error(f"MCP2221A Timeout: {e}")
        except MCP2221AError as e:
            raise PCA9535Error(f"MCP2221A Error: {e}")

""" Write to a pair of registers in the PCA9535 that is attached to the MCP2221A on the Dev Tool

The PCA9535 is a 16-bit device, and there are 4 pairs of registers:

0-1 are read only input states (regardless of whether the GPIOs are configured as inputs or outputs)
2-3 are output states
4-5 are polarity inversion
7-8 are direction

Writes will ping pong between the two registers in a pair, starting with the addressed register, thus it is permissable
to write more than 2 bytes of data.

No value is returned
Raises: ValueError if the length of data to be written exceeds the maximum length supported
        PCA9535Error for a variety of error conditions
"""
def pca9535_write(out_ep, in_ep, reg, data, errors=False):
    start = 0
    packet = 1

    if len(data) > 65534:
        raise ValueError(f"Trying to send too much data: {len(data)} bytes, max 65534 supported")

    while True:
        if start == 0:
            # Prepare the tx buffer for the first chunk
            tx_buf = []
            tx_buf.append(0x90)                                         # I2C write data
            tx_buf += list(map(int, struct.pack("<H", len(data) + 1)))  # Write n bytes
            tx_buf.append(PCA9535_I2C_ADDR << 1)                        # Slave address
            tx_buf.append(reg)                                          # Register to start writing to

            # Add upto 59 bytes of data to the initial packet
            tx_buf += data[0:59]
            tx_buf += [0] * (64 - len(tx_buf))
            start += 59
        else:
            # Send a further packet containing upto 64 bytes
            tx_buf = data[start:start + 64]
            tx_buf += [0] * (64 - len(tx_buf))
            start += 64

        pca9535_transfer(out_ep, in_ep, tx_buf, errors=errors)

        # All data sent successfully
        if start >= len(data):
            return
        
        packet += 1

""" Read from a pair of registers in the PCA9535 that is attached to the MCP2221A on the Dev Tool

See pca9535_write() for a description of registers.

Like writing, reads from the PCA9535 will ping pong between registers in a pair, thus it is permissable to read more
than 2 bytes.

Returns: data (list of int, being the data that was read from the PCA9535)
Raises: ValueError if the length of data to be read exceeds the maximum length supported
        PCA9535Error for a variety of error conditions
"""
def pca9535_read(out_ep, in_ep, reg, length, errors=False):
    if length > 60:
        raise ValueError(f"Trying to read too much data: {length} bytes, max 60 supported (for now)")

    # Prepare the tx buffer - the first step is to write the register address to start reading from
    tx_buf = [0] * 64
    tx_buf[0] = 0x94                    # I2C write data no stop
    tx_buf[1] = 1                       # Write 1 byte (register address)
    tx_buf[3] = PCA9535_I2C_ADDR << 1   # Slave address
    tx_buf[4] = reg                     # Register address

    pca9535_transfer(out_ep, in_ep, tx_buf, errors=errors)

    # The second step is to issue a read with a repeated start
    tx_buf = []
    tx_buf.append(0x93)                                     # I2C read data repeated start
    tx_buf += list(map(int, struct.pack("<H", length)))     # Read n bytes
    tx_buf.append(PCA9535_I2C_ADDR << 1)                # Slave address
    tx_buf += [0] * (64 - len(tx_buf))

    pca9535_transfer(out_ep, in_ep, tx_buf, errors=errors)

    # The final step is to get the data that has been read
    tx_buf = [0] * 64
    tx_buf[0] = 0x40          # Get I2C data

    try:
        success, rx_buf = mcp2221a_transfer(out_ep, in_ep, tx_buf, errors=errors)

        if success is False:
            raise PCA9535Error("Error reading data from MCP2221A")
    except MCP2221ATimeout as e:
        raise PCA9535Error(f"MCP2221A Timeout: {e}")
    except MCP2221AError as e:
        raise PCA9535Error(f"MCP2221A Error: {e}")
    
    # On success, return only the data that has been read
    return rx_buf[4:4 + length]


""" Initialise a Dev Tool instance, setting GPIOs to default states.

Returns: success (bool indicating whether the Dev Tool has been initialised (True) or not (False))
"""
def init(out_ep, in_ep, errors=False):
    print("Initialising Dev Tool: ", end="", flush=True)

    # First step, turn off MCP2221A GP2 (IN USE LED)
    try:
        mcp2221a_set_gp2(out_ep, in_ep, False, errors=errors)
    except MCP2221AError as e:
        print("FAILED")
        print(f"ERROR: Unable to disable IN USE LED: {e}")

        return False

    # Configure I2C clock for 100KHz operation
    tx_buf = [0] * 64
    tx_buf[0] = 0x10                # Status/set parameters
    tx_buf[3] = 0x20                # Set I2C communication speed
    tx_buf[4] = 118                 # (12MHz / 100KHz) - 2

    try:
        mcp2221a_transfer(out_ep, in_ep, tx_buf, errors=errors)
    except MCP2221AError as e:
        print("FAILED")

        if errors is True:
            print(f"ERROR: Unable to set I2C bus clock: {e}")
        
        return

    # Next, set defaults for the PCA9535:
    #
    # Ouputs (2-3): 0x0F67
    #   0000 1111 .... ....     Uninitialised Interrupt vector number
    #   .... .... .1.. ....     BUSRESET/ negated
    #   .... .... ..1. ....     Backplane power enabled
    #   .... .... .... 0...     Vectored interrupt
    #   .... .... .... .111     IPL 0 (no active interrupt request)
    #
    # Polarity (4-5): 0x0080
    #   .... .... 1... ....     SYSRESET/ readback
    #
    # Directions (6-7): 0x0090
    #   0000 0000 .... ....     Interrupt vector number is output
    #   .... .... 1... ....     SYSRESET/ readback is an input
    #   .... .... .0.. ....     BUSRESET/ is an output
    #   .... .... ..0. ....     Backplane power enable is an output
    #   .... .... ...1 ....     Interrupt Acknowledged is an input
    #   .... .... .... 0...     AUTOVEC is an output
    #   .... .... .... .000     Iterrupt Priority Level is an output
    default_outputs = 0x0F67
    default_polarity = 0x0080
    default_dirs = 0x0090

    # Output states
    try:
        pca9535_write(out_ep, in_ep, 0x2, list(map(int, struct.pack("<H", default_outputs))), errors=errors)
    except PCA9535Error as e:
        print("FAILED")

        if errors is True:
            print(f"ERROR: Unable to set default output values: {e}")

        return False

    # Input polarity inversions
    try:
        pca9535_write(out_ep, in_ep, 0x4, list(map(int, struct.pack("<H", default_polarity))), errors=errors)
    except PCA9535Error as e:
        print("FAILED")

        if errors is True:
            print(f"ERROR: Unable to set input polarity inversions: {e}")

        return False

    # Directions
    try:
        pca9535_write(out_ep, in_ep, 0x6, list(map(int, struct.pack("<H", default_dirs))), errors=errors)
    except PCA9535Error as e:
        print("FAILED")

        if errors is True:
            print(f"ERROR: Unable to set GPIO directions: {e}")

        return False

    # Workaround? Write ADC Vref settings to SRAM or it wont return the correct value
    tx_buf = [0] * 64
    tx_buf[0] = 0x60                # Set SRAM settings
    tx_buf[5] = 0x80 | 3 << 1 | 1   # Set ADC voltage reference (VRM, 4.096V)

    try:
        mcp2221a_transfer(out_ep, in_ep, tx_buf, errors=errors)
    except MCP2221AError as e:
        print("FAILED")

        if errors is True:
            print(f"ERROR: Unable to set SRAM settings (ADC configuration): {e}")
        
        return

    # Finally, turn on MCP2221A GP2 (IN USE LED) to indicate the tool is initialised and ready to use
    try:
        mcp2221a_set_gp2(out_ep, in_ep, True, errors=errors)
    except MCP2221AError as e:
        print("FAILED")
        print(f"ERROR: Unable to enable IN USE LED: {e}")

        return False
    
    # Successfully initialised
    print("OK")
        
    return True


""" Assert, negate, or generate a pulse on the BUSRESET signal to reset the target system

If assert_flag and negate_flag are both True, this effects a reset pulse.

No value is returned
"""
def reset(out_ep, in_ep, assert_flag, negate_flag, errors=False):
    def assert_busreset(out_ep, in_ep, outputs, errors=False):
        # Assert BUSRESET. Also return IPL to 0 to negate any pending interrupts.
        outputs &= ~BitMasks.BUSRESET_MASK
        outputs |= BitMasks.IPL_MASK

        out_data = list(map(int, struct.pack("<H", outputs)))

        pca9535_write(out_ep, in_ep, 0x2, out_data, errors=errors)

        return outputs

    def negate_busreset(out_ep, in_ep, outputs, errors=False):
        # Negate BUSRESET
        outputs |= BitMasks.BUSRESET_MASK

        out_data = list(map(int, struct.pack("<H", outputs)))

        pca9535_write(out_ep, in_ep, 0x2, out_data, errors=errors)

        return outputs

    outputs = 0
    separator = ""

    print("Resetting target system: ", end="", flush=True)

    try:
        # Read in the current state of the PCA9535 outputs, operations will be done relative to the current state
        data = pca9535_read(out_ep, in_ep, 0x2, 2, errors=errors)
    
        # Translate returned data back into an integer
        outputs = struct.unpack("<H", data)[0]
    except PCA9535Error as e:
        print("FAILED")

        if errors is True:
            print(f"ERROR: Failed to read current state of outputs from PCA9535: {e}")
        
        return

    # Handle assert case first, for reset pulse sequences
    if assert_flag is True:
        # Assert BUSRESET
        try:
            outputs = assert_busreset(out_ep, in_ep, outputs, errors=errors)
        except PCA9535Error as e:
            print("FAILED")

            if errors is True:
                print(f"ERROR: Failed to assert BUSRESET (pulse/1): {e}")

            return

        print("asserted", end="", flush=True)

        # If negate_flag is also set, we're doing a reset pulse. Include a delay between assert and negate.
        if negate_flag is True:
            separator = ", "

            # Delay
            time.sleep(0.5)

    if negate_flag is True:
        # Negate BUSRESET
        try:
            outputs = negate_busreset(out_ep, in_ep, outputs, errors=False)
        except PCA9535Error as e:
            print(", FAILED")

            if errors is True:
                print(f"ERROR: Failed to negate BUSRESET (pulse/2): {e}")

            return

        # Wait for SYSRESET/ to be negated
        while True:
            try:
                data = pca9535_read(out_ep, in_ep, 0, 2, errors=errors)

                # Translate returned data back into an integer
                inputs = struct.unpack("<H", data)[0]
            except PCA9535Error as e:
                print(f"{separator}FAILED")

                if errors is True:
                    print(
                        "ERROR: While waiting for SYSRESET/ to negate, failed to read current state of outputs from "
                        f"PCA9535: {e}"
                    )
                
                return

            if not inputs & BitMasks.SYSRESET_MASK:
                # SYSRESET/ is negated, exit loop
                print(f"{separator}negated", end="", flush=True)

                break

    print(", OK")

    # Succeeded

""" Turn backplane power on, off, or perform power cycle

If on_flag and off_flag are both True, this effects a power cycle.

No value is returned
"""
def power(out_ep, in_ep, on_flag, off_flag, errors=False):
    def power_on(out_ep, in_ep, outputs, errors=False):
        # Turn power on by setting POWER_EN bit
        outputs |= BitMasks.POWER_EN_MASK

        out_data = list(map(int, struct.pack("<H", outputs)))

        pca9535_write(out_ep, in_ep, 0x2, out_data, errors=errors)

        return outputs

    def power_off(out_ep, in_ep, outputs, errors=False):
        # Turn power off by clearing POWER_EN bit
        outputs &= ~BitMasks.POWER_EN_MASK

        out_data = list(map(int, struct.pack("<H", outputs)))

        pca9535_write(out_ep, in_ep, 0x2, out_data, errors=errors)

        return outputs
    
    outputs = 0
    separator = ""

    print("Switching power to main +5V supply: ", end="", flush=True)

    try:
        # Read in the current state of the PCA9535 outputs, operations will be done relative to the current state
        data = pca9535_read(out_ep, in_ep, 0x2, 2, errors=errors)
    
        # Translate returned data back into an integer
        outputs = struct.unpack("<H", data)[0]
    except PCA9535Error as e:
        print("FAILED")

        if errors is True:
            print(f"ERROR: Failed to read current state of outputs from PCA9535: {e}")
        
        return
    
    # Handle the power off case first, for power cycle sequences
    if off_flag is True:
        # Turn power off
        try:
            outputs = power_off(out_ep, in_ep, outputs, errors=errors)
        except PCA9535Error as e:
            print("FAILED")

            if errors is True:
                print(f"ERROR: Failed to turn backplane power off: {e}")

            return
        
        # Loop until the backplane voltage drops below 0.1V
        while True:
            try:
                voltage = mcp2221a_get_adc1(out_ep, in_ep, errors=errors)

                if voltage < 0.1:
                    break
            except MCP2221AError as e:
                print("FAILED")

                if errors is True:
                    print(f"ERROR: Failed to get backplane voltage during power off: {e}")
                
                return
            
            time.sleep(0.1)
        
        print("powered off", end="", flush=True)

        # If on_flag is also set, we're doing a power cycle
        if on_flag is True:
            separator = ", "

    if on_flag is True:
        # Turn power on
        try:
            outputs = power_on(out_ep, in_ep, outputs, errors=errors)
        except PCA9535Error as e:
            print(f"{separator}FAILED")

            if errors is True:
                print(f"ERROR: Failed to turn backplane power on (cycle): {e}")

            return
        
        # Loop until the backplane voltage rises above 4.9V
        while True:
            try:
                voltage = mcp2221a_get_adc1(out_ep, in_ep, errors=errors)

                if voltage > 4.9:
                    break
            except MCP2221AError as e:
                print(f"{separator}FAILED")

                if errors is True:
                    print(f"ERROR: Failed to get backplane voltage during power on: {e}")
                
                return
            
            time.sleep(0.1)
        
        print(f"{separator}powered on", end="", flush=True)

    print(", OK")

    # Succeeded

""" Generate interrupts

If vector is None, the interrupt with be auto-vectored.

No value is returned
"""
def interrupt(out_ep, in_ep, vector, irq, errors=False):
    outputs = 0

    if not 0 <= irq <= 7:
        print("ERROR: IRQ number must be between 1 and 7 inclusive")

        return

    if vector is not None:
        if not 0 <= vector <= 0xFF:
            print("ERROR: Vector number must be between 0 and 0xFF (255) inclusive")

            return

    if vector is not None:
        print(f"Vectored interrupt request 0x{vector:02X} ({vector}) on IRQ {irq}: ", end="", flush=True)
    else:
        print(f"Auto-vectored interrupt request on IRQ {irq}: ", end="", flush=True)

    try:
        # Read in the current state of the PCA9535 outputs, operations will be done relative to the current state
        data = pca9535_read(out_ep, in_ep, 0x2, 2, errors=errors)
    
        # Translate returned data back into an integer
        outputs = struct.unpack("<H", data)[0]
    except PCA9535Error as e:
        print("FAILED")

        if errors is True:
            print(f"ERROR: Failed to read current state of outputs from PCA9535: {e}")
        
        return

    # Configure settings for the interrupt to be requested
    outputs |= BitMasks.IPL_MASK    # Reset the IPL to negate any existing interrupt request

    if vector is not None:
        # Doing a vectored interrupt. Set the vector number and clear the AUTOVECTOR bit.
        outputs &= ~(BitMasks.VECTOR_MASK | BitMasks.AUTOVEC_MASK)
        outputs |= vector << BitMasks.VECTOR_POS
    else:
        # Auto-vectored interrupt. Set the AUTOVECTOR bit.
        outputs |= BitMasks.AUTOVEC_MASK

    try:
        out_data = list(map(int, struct.pack("<H", outputs)))

        pca9535_write(out_ep, in_ep, 0x2, out_data, errors=errors)
    except PCA9535Error as e:
        print("FAILED")

        if errors is True:
            print(f"ERROR: Failed to configure interrupt settings: {e}")

        return

    # Set the IPL for the interrupt, this executes the request
    outputs &= ~BitMasks.IPL_MASK
    outputs |= (irq ^ BitMasks.IPL_MASK) << BitMasks.IPL_POS

    try:
        out_data = list(map(int, struct.pack("<H", outputs)))

        pca9535_write(out_ep, in_ep, 0x2, out_data, errors=errors)
    except PCA9535Error as e:
        print("FAILED")

        if errors is True:
            print(f"ERROR: Failed to set new IPL: {e}")

        return

    if irq == 0:
        # Interrupt request should now be negated, so we can return
        print("OK")

        return
    
    print("requested", end="", flush=True)

    # Now must wait for ACKD to become set. This indicates that the CPU acknowledged the interrupt. The IPL can then
    # be returned to 0 to negate the interrupt request.
    while True:
        try:
            # Read in the current state of the PCA9535 inputs
            data = pca9535_read(out_ep, in_ep, 0, 2, errors=errors)
        
            # Translate returned data back into an integer
            inputs = struct.unpack("<H", data)[0]
        except PCA9535Error as e:
            print(", FAILED")

            if errors is True:
                print(f"ERROR: Failed to read current state of inputs from PCA9535: {e}")
            
            return

        if inputs & BitMasks.ACKD_MASK:
            # ACKD is set, exit loop
            print(", acknowledged", end="", flush=True)

            break

    # Negate the interrupt request
    outputs |= BitMasks.IPL_MASK

    try:
        out_data = list(map(int, struct.pack("<H", outputs)))

        pca9535_write(out_ep, in_ep, 0x2, out_data, errors=errors)
    except PCA9535Error as e:
        print(", FAILED")

        if errors is True:
            print(f"ERROR: Failed to negate the interrupt request: {e}")

        return
    
    print(", OK")

    return


""" For argparse, translates parameters to integers
"""
def number(x):
    return int(x, 0)

def main():
    errors = True

    parser = argparse.ArgumentParser(
        description="Interact with a system via the COMETbus Dev Tool"
    )
    parser.set_defaults(which=None)
    parser.set_defaults(init_list_flag=False)
    parser.set_defaults(assert_flag=False)
    parser.set_defaults(negate_flag=False)
    parser.set_defaults(cycle_flag=False)
    parser.set_defaults(on_flag=False)
    parser.set_defaults(off_flag=False)
    parser.set_defaults(voltage_flag=False)
    

    subparsers = parser.add_subparsers()

    ####################################################################################################################
    init_parser = subparsers.add_parser(
        "init", help="Initialise a Dev Tool",
        description="Before using a Dev Tool, it should be initialised to set GPIOs to the correct states etc. Can "
                    "also be used to restore a Dev Tool to initial states during use."
    )
    init_parser.set_defaults(which="init")
    init_action_group = init_parser.add_mutually_exclusive_group()
    init_action_group.add_argument(
        "--list",
        dest="init_list_flag", action="store_true",
        help=f"List enumerated Dev Tools by serial number of their MCP2221A"
    )
    ####################################################################################################################
    reset_parser = subparsers.add_parser(
        "reset", help="Reset the target system",
        description="Generate reset pulses or assert/negate to reset and run a target system. If --cycle is specified, "
                    "BUSRESET is asserted for a short period (500ms) before being negated."
    )
    reset_parser.set_defaults(which="reset")
    reset_op_group = reset_parser.add_mutually_exclusive_group(required=True)
    reset_op_group.add_argument(
        "--cycle",
        dest="cycle_flag", action="store_true",
        help="BUSRESET is asserted and then negated"
    )
    reset_op_group.add_argument(
        "--assert",
        dest="assert_flag", action="store_true",
        help="Assert the BUSRESET signal"
    )
    reset_op_group.add_argument(
        "--negate",
        dest="negate_flag", action="store_true",
        help="Negate the BUSRESET signal"
    )
    ####################################################################################################################
    power_parser = subparsers.add_parser(
        "power", help="Power cycle the target system",
        description="Power cycle or turn the power on or off to the target system. A power cycle involves disabling "
                    "the main +5V supply and monitoring the voltage level until it falls below 0.1V, at which point "
                    "the power is re-enabled and the voltage is once again monitored until it rises above 4.9V."
    )
    power_parser.set_defaults(which="power")
    power_op_group = power_parser.add_mutually_exclusive_group(required=True)
    power_op_group.add_argument(
        "--cycle",
        dest="cycle_flag", action="store_true",
        help="Backplane power is turned off and then back on"
    )
    power_op_group.add_argument(
        "--on",
        dest="on_flag", action="store_true",
        help="Backplane power is turned on"
    )
    power_op_group.add_argument(
        "--off",
        dest="off_flag", action="store_true",
        help="Backplane power is turned off"
    )
    ####################################################################################################################
    interrupt_parser = subparsers.add_parser(
        "interrupt", help="Generate interrupts",
        description="Allows vectored and auto-vectored interrupts to be generated. If --vector is not specified, the "
                    "interrupt will be auto-vectored."
    )
    interrupt_parser.set_defaults(which="interrupt")
    interrupt_parser.add_argument(
        "--vector",
        dest="vector", type=number, default=None, required=False,
        help="The vector number to supply for a vectored interrupt"
    )
    interrupt_parser.add_argument(
        "IRQ", type=number, nargs=1, default=None,
        help="The IRQ number to generate the interrupt on"
    )
    ####################################################################################################################
    env_parser = subparsers.add_parser(
        "env", help="Read environmental values from the Dev Tool"
    )
    env_parser.set_defaults(which="env")
    env_op_group = env_parser.add_mutually_exclusive_group(required=True)
    env_op_group.add_argument(
        "--voltage",
        dest="voltage_flag", action="store_true",
        help="Read the voltage of the main +5V power rail"
    )
    ####################################################################################################################

    args = parser.parse_args()

    start = time.time()

    if args.which == "init" and args.init_list_flag is True:
        # If listing Dev Tools, dont need to check if the env var is set
        dev_tool_list()
    else:
        # For all other operations, including the standalone init operation, check that the env var is set
        sn = os.getenv(DEV_TOOL_SN_VAR)

        if sn is None:
            print(
                f"ERROR: {DEV_TOOL_SN_VAR} environment variable is not set. Use \"devtool.py init --list\" to "
                f"determine the serial number of your Dev Tool, and configure the environment variable before "
                f"retrying the operation."
            )

            return
        
        # Get the OUT and IN endpoints for this Dev Tool instance
        out_ep, in_ep = get_devtool_by_serial(sn)

        if out_ep is not None and in_ep is not None:
            # print(f"Working with Dev Tool s/n {sn}")
            pass
        else:
            print(f"ERROR: Could not find Dev Tool by s/n {sn} - is it connected?")

            return
        
        # Perform the action
        if args.which == "init":
            init(out_ep, in_ep, errors=errors)
        else:
            # For anything other than init, check the current initialisation status, which is determined by the state
            # of GP2 (IN USE LED)
            try:
                state = mcp2221a_get_gp2(out_ep, in_ep, errors=errors)
            except MCP2221AError as e:
                print(f"ERROR: Failed to get initialisation status of Dev Tool: {e}")

                return
            
            if state is False:
                success = init(out_ep, in_ep, errors=errors)

                if success is not True:
                    return

            # Perform the action
            if args.which == "reset":
                if args.cycle_flag is True:
                    # Generating a reset pulse, set both flags to perform both actions
                    reset_parser.set_defaults(assert_flag=True)
                    reset_parser.set_defaults(negate_flag=True)
                    args = parser.parse_args()

                reset(out_ep, in_ep, args.assert_flag, args.negate_flag, errors=errors)
            elif args.which == "power":
                if args.cycle_flag is True:
                    # For a power cycle, set both the on and off flags to perform both actions
                    power_parser.set_defaults(on_flag=True)
                    power_parser.set_defaults(off_flag=True)
                    args = parser.parse_args()

                power(out_ep, in_ep, args.on_flag, args.off_flag, errors=errors)
            elif args.which == "interrupt":
                interrupt(out_ep, in_ep, args.vector, args.IRQ[0], errors=errors)
            elif args.which == "env":
                if args.voltage_flag is True:
                    try:
                        voltage = mcp2221a_get_adc1(out_ep, in_ep, errors=errors)

                        print(f"Main +5V rail voltage: {voltage:0.2f}V")
                    except MCP2221AError as e:
                        print(f"ERROR: Unable to read voltage: {e}")

    duration = time.time() - start

    if SHOW_TIME is True:
        print("Done in %.3fs" % duration)

    # Done

if __name__ == "__main__":
    main()
