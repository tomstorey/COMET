#!/usr/bin/env python3

from enum import IntEnum
import argparse
from serial import Serial
import struct
import os
import time

VERSION = 20251001

# The name of the environment variables that holds the path to the serial port to use, and the baud rate
PORT_VAR = "COMET_LOADER_PORT"
BAUD_VAR = "COMET_LOADER_BAUD"

RETRIES = 10

# The number of bytes to be transferred as part of a flash program chunk. Must be sync'd with bootloader!
FLASH_PROGRAM_CHUNK = 256

# Commands that can be sent to the bootloader
class Command(IntEnum):
    PING = 1
    PEEK = 2
    POKE = 3
    BOOT = 4
    JMP = 5
    JSR = 6
    FLASH_ID = 7
    FLASH_CHIP_ERASE = 8
    FLASH_PROGRAM = 9

# Responses that can be received from the bootloader
class Response(IntEnum):
    ACK = 1
    NAK = 2

class Flags(IntEnum):
    ALT = 0x1
    BLOCK = 0x2
    SIXTEEN = 0x4

FLASH_CHIPS = [
    {
        "mfg": (0x01, "AMD"),
        "devices": [
            {
                "model": (0x51, "Am29F200xT"), "size": 256,
                "erase_blocks": [(64 * 1024, 3), (32 * 1024, 1), (8 * 1024, 2), (16 * 1024, 1), ]
            },
            {
                "model": (0x57, "Am29F200xB"), "size": 256,
                "erase_blocks": [(16 * 1024, 1), (8 * 1024, 2), (32 * 1024, 1), (64 * 1024, 3), ]
            },
            {
                "model": (0x23, "Am29F400xT"), "size": 512,
                "erase_blocks": [(64 * 1024, 7), (32 * 1024, 1), (8 * 1024, 2), (16 * 1024, 1), ]
            },
            {
                "model": (0xAB, "Am29F400xB"), "size": 512,
                "erase_blocks": [(16 * 1024, 1), (8 * 1024, 2), (32 * 1024, 1), (64 * 1024, 7), ]
            },
            {
                "model": (0xD6, "Am29F800xT"), "size": 1024,
                "erase_blocks": [(64 * 1024, 15), (32 * 1024, 1), (8 * 1024, 2), (16 * 1024, 1), ]
            },
            {
                "model": (0x58, "Am29F800xB"), "size": 1024,
                "erase_blocks": [(16 * 1024, 1), (8 * 1024, 2), (32 * 1024, 1), (64 * 1024, 15), ]
            },
            {
                "model": (0xD6, "Am29F160xT"), "size": 2048,
                "erase_blocks": [(64 * 1024, 31), (32 * 1024, 1), (8 * 1024, 2), (16 * 1024, 1), ]
            },
            {
                "model": (0x58, "Am29F160xB"), "size": 2048,
                "erase_blocks": [(16 * 1024, 1), (8 * 1024, 2), (32 * 1024, 1), (64 * 1024, 31), ]
            },
        ]
    }
]

def send_command(ser, cmd):
    ser.write(bytes([cmd]))
    ser.flush()

def await_response(ser, retries, timeout_char=".") -> int:
    tries = 0
    response = None

    while True:
        try:
            response = ord(ser.read(size=1))

            if response > 0:
                break
        except TypeError:
            tries += 1

            print(timeout_char, end="", flush=True)

            if tries >= retries:
                break

    return response

def check_bootloader_available(ser) -> bool:
    retries = 0

    while True:
        send_command(ser, Command.PING)

        if await_response(ser, 1) == Response.ACK:
            return True
        else:
            retries += 1

            if retries == RETRIES:
                return False

def hexdump(data, addr, flags):
    """ Prints a nicely formatted hex dump of the supplied data, with user
    supplied address to display on the left hand side.

    Data is indented according to the address supplied such that it always
    displays most naturally aligned to 16 byte boundaries.
    """
    print(" -------- -------- -------- -------- --------  ----------------")

    dataptr = 0

    if not flags & Flags.BLOCK:
        line_spaces = addr % 16
        addr &= ~(0xF)
    else:
        line_spaces = 0

    while dataptr < len(data):
        bytesleft = len(data) - dataptr

        if line_spaces > 0:
            line_bytes = 16 - line_spaces
        else:
            line_bytes = 16 if bytesleft > 16 else bytesleft

        print(f" {addr:08x} ", end="")

        if line_spaces > 0:
            for i in range(line_spaces):
                print("  ", end="")

                if i % 4 == 3:
                    print(" ", end="")

        ctr = line_spaces

        for i in range(16 - line_spaces):
            if i < line_bytes and i < len(data):
                print(f"{data[dataptr + i]:02x}", end="")
            else:
                print("  ", end="")

            if ctr % 4 == 3:
                print(" ", end="")

            ctr += 1

        print(" ", end="")

        if line_spaces > 0:
            print(" " * line_spaces, end="")

        for i in range(line_bytes):
            if i < len(data):
                c = data[dataptr + i : dataptr + i + 1]

                if c[0] >= 0x20 and c[0] < 0x7f:
                    print(c.decode("latin-1"), end="")
                else:
                    print(".", end="")
            else:
                print(" ", end="")

        print()

        if flags & Flags.ALT:
            addr += 32
        else:
            if not flags & Flags.BLOCK:
                addr += 16

        dataptr += line_bytes
        line_spaces = 0

def peek(ser, flags, address, length, word_flag, long_flag, file, returndata=False):
    # Pack some big endian values
    address_be = struct.pack(">L", address)
    length_be = struct.pack(">L", length)

    # Prepare the command to be transmitted
    if word_flag:
        cmd_tx = bytes([Command.PEEK, flags, 2]) + address_be + length_be
    elif long_flag:
        cmd_tx = bytes([Command.PEEK, flags, 4]) + address_be + length_be
    else:
        cmd_tx = bytes([Command.PEEK, flags, 1]) + address_be + length_be

    # Send it
    if flags & Flags.ALT:
        print(f"Reading {length} bytes from 0x{address:08X} on alternating addresses: ", end="", flush=True)
    else:
        print(f"Reading {length} bytes from 0x{address:08X}: ", end="", flush=True)

    ser.write(cmd_tx)
    ser.flush()

    if await_response(ser, RETRIES) != Response.ACK:
        print("Failed: transfer not acknowledged")

        return

    # Receive data into an array
    to_rx = length
    data_rx = []
    failed = 0

    while to_rx > 0:
        try:
            data_rx.append(ord(ser.read(size=1)))
        except TypeError:
            failed += 1

            print(".", end="", flush=True)

            if failed == RETRIES:
                print(" Failed: transfer failed, too many timeouts")

                return
            else:
                continue

        to_rx -= 1

        if to_rx % 100 == 0:
            print("+", end="", flush=True)

    if failed == 0:
        print(" OK")
    else:
        print(
            " WARNING: Data is likely not valid due to issues when receiving"
        )

    if returndata is True:
        return data_rx
    else:
        # If a file has not been specified, give a hexdump of the received data, otherwise write it to a file
        if file is None:
            hexdump(bytes(data_rx), address, flags)
        else:
            with open(file, "w+b") as f:
                f.write(bytes(data_rx))

def convert_hex_to_bytes(data: str) -> bytes:
    offset = 0

    chars = []

    if len(data) & 1 == 1:
        data = f"0{data}"

    while True:
        if offset >= len(data):
            break

        if data[offset] == " ":
            offset += 1

            continue

        text = data[offset:(offset + 2)]
        offset += 2

        try:
            val = int(text, 16)
        except ValueError:
            raise ValueError(f"\"{text}\" is not valid hex formatted data")

        chars.append(val)

    return bytes(chars)

def poke(ser, flags, address, word_flag, long_flag, data):
    # Take the string out of the list it is supplied in
    # data = data[0]

    # Left pad with zeroes
    if word_flag:
        if len(data) % 4:
            data = "0" * (4 - len(data) % 4) + data
    elif long_flag:
        if len(data) % 8:
            data = "0" * (8 - len(data) % 8) + data
    else:
        if len(data) % 2:
            data = "0" * (2 - len(data) % 2) + data

    length = len(data) // 2

    # Convert to bytes for transmission
    data = convert_hex_to_bytes(data)

    # Pack some big endian values
    address_be = struct.pack(">L", address)
    length_be = struct.pack(">L", length)

    # Prepare the command to be transmitted
    if word_flag:
        cmd_tx = bytes([Command.POKE, flags, 2]) + address_be + length_be + data
    elif long_flag:
        cmd_tx = bytes([Command.POKE, flags, 4]) + address_be + length_be + data
    else:
        cmd_tx = bytes([Command.POKE, flags, 1]) + address_be + length_be + data

    # Send it
    if flags & Flags.ALT:
        print(f"Writing {length} bytes to 0x{address:08X} on alternating addresses: ", end="", flush=True)
    else:
        print(f"Writing {length} bytes to 0x{address:08X}: ", end="", flush=True)

    ser.write(cmd_tx)
    ser.flush()

    if await_response(ser, RETRIES) != Response.ACK:
        print("Failed: transfer not acknowledged")

        return

    print("OK")

def boot(ser, address):
    # Pack some big endian values
    address_be = struct.pack(">L", address)

    # Prepare the command to be transmitted
    cmd_tx = bytes([Command.BOOT]) + address_be

    # Send it
    print(f"Transfer execution to address 0x{address:08x} via simulated boot: ", end="", flush=True)

    ser.write(cmd_tx)
    ser.flush()

    if await_response(ser, RETRIES) != Response.ACK:
        print("Failed: transfer not acknowledged")

        return

    print("OK")

def jmp(ser, address):
    # Pack some big endian values
    address_be = struct.pack(">L", address)

    # Prepare the command to be transmitted
    cmd_tx = bytes([Command.JMP]) + address_be

    # Send it
    print(f"Transfer execution to address 0x{address:08x} via JMP: ", end="", flush=True)

    ser.write(cmd_tx)
    ser.flush()

    if await_response(ser, RETRIES) != Response.ACK:
        print("Failed: transfer not acknowledged")

        return

    print("OK")

def jsr(ser, address):
    # Pack some big endian values
    address_be = struct.pack(">L", address)

    # Prepare the command to be transmitted
    cmd_tx = bytes([Command.JSR]) + address_be

    # Send it
    print(f"Transfer execution to address 0x{address:08x} via JSR: ", end="", flush=True)

    ser.write(cmd_tx)
    ser.flush()

    if await_response(ser, RETRIES) != Response.ACK:
        print("Failed: transfer not acknowledged")

        return

    print("OK")

def number(x):
    return int(x, 0)

def flash_get_mfg(mfg_id, return_struct=False):
    for mfg in FLASH_CHIPS:
        data = mfg.get("mfg")

        if data is None:
            continue

        if data[0] == mfg_id:
            if return_struct is True:
                return mfg
            else:
                return data[1]

    return {}

def flash_get_device(mfg_id, dev_id):
    mfg = flash_get_mfg(mfg_id, return_struct=True)
    devices = mfg.get("devices")

    if devices is not None:
        for device in devices:
            model = device.get("model")

            if model is None:
                continue

            if model[0] == dev_id:
                return model[1], device.get("size", 0)

    return "Unknown", 0

def flash_id(ser, flags, address, return_data=False):
    # Pack some big endian values
    address_be = struct.pack(">L", address)

    # Prepare the command to be transmitted
    cmd_tx = bytes([Command.FLASH_ID, flags]) + address_be

    # Send it
    print(f"Identifing flash memory at 0x{address:08X}: ", end="", flush=True)

    ser.write(cmd_tx)
    ser.flush()

    if await_response(ser, RETRIES) != Response.ACK:
        print("Failed: transfer not acknowledged")

        return

    # Receive data into an array
    to_rx = 2
    data_rx = []
    failed = 0

    while to_rx > 0:
        try:
            data_rx.append(ord(ser.read(size=1)))
        except TypeError:
            failed += 1

            print(".", end="", flush=True)

            if failed == RETRIES:
                print(" Failed: transfer failed, too many timeouts")

                return
            else:
                continue

        to_rx -= 1

        if to_rx % 100 == 0:
            print("+", end="", flush=True)

    if failed == 0:
        print(" OK")
    else:
        print(
            " WARNING: Data is likely not valid due to issues when receiving"
        )

    if return_data is True:
        return data_rx

    # Get corresponding manufacturer and device strings from IDs
    mfg_id = data_rx[0]
    dev_id = data_rx[1]

    mfg_string = flash_get_mfg(mfg_id)
    dev_string, dev_size = flash_get_device(mfg_id, dev_id)

    print(f"Manufacturer: 0x{mfg_id:02X}, {mfg_string}")
    print(f"Device:       0x{dev_id:02X}, {dev_string}")
    print(f"Size:         {dev_size}K")

    return None

def flash_chip_erase(ser, flags, address):
    # Pack some big endian values
    address_be = struct.pack(">L", address)

    # Prepare the command to be transmitted
    cmd_tx = bytes([Command.FLASH_CHIP_ERASE, flags]) + address_be

    # Send it
    print(f"Erasing flash memory at 0x{address:08X}: ", end="", flush=True)

    ser.write(cmd_tx)
    ser.flush()

    if await_response(ser, RETRIES) != Response.ACK:
        print("Failed: transfer not acknowledged")

        return

    # Set up the spinner
    spinner = ["|", "/", "-", "\\"]
    spin_ctr = 1

    print(spinner[0], end="", flush=True)

    while True:
        response = await_response(ser, 0, timeout_char="")

        # Prepare to overwrite spinner
        print("\b", end="", flush=True)

        if response is None:
            # Advance the spinner
            print(spinner[spin_ctr & 0x3], end="", flush=True)
            spin_ctr += 1
        elif response == Response.ACK:
            print("OK")

            break
        elif response == Response.NAK:
            print("Failed: erase error")

            break

def flash_program(ser, flags, address, data_wr):
    length = len(data_wr)

    # Pack some big endian values
    address_be = struct.pack(">L", address)
    length_be = struct.pack(">L", length)

    # Prepare the command to be transmitted
    cmd_tx = bytes([Command.FLASH_PROGRAM, flags]) + address_be + length_be

    print(f"Writing {length} bytes to flash memory at 0x{address:08X}: ", end="", flush=True)

    ser.write(cmd_tx)
    ser.flush()

    i = 0

    while length > 0:
        # Send up to FLASH_PROGRAM_CHUNK bytes of data to be programmed
        if length > FLASH_PROGRAM_CHUNK:
            c = FLASH_PROGRAM_CHUNK
        else:
            c = length

        data_tx = data_wr[i:i+FLASH_PROGRAM_CHUNK]
        ser.write(data_tx)
        ser.flush()

        response = await_response(ser, RETRIES, timeout_char="")

        if response == Response.ACK:
            print("+", end="", flush=True)
        else:
            print(f" Failed: programming failed beyond address 0x{address+i:08x}")

            return

        i += FLASH_PROGRAM_CHUNK
        length -= c

    # If we get this far, everything succeeded and the flash memory should now be programmed
    print(" OK")

def main():
    parser = argparse.ArgumentParser(
        description="Load application software or read/write memory via serial connection"
    )
    parser.set_defaults(which=None)
    parser.set_defaults(alt_flag=False)
    parser.set_defaults(block_flag=False)
    parser.set_defaults(word_flag=False)
    parser.set_defaults(long_flag=False)
    parser.set_defaults(data_flag=False)
    parser.set_defaults(sixteen_flag=False)

    subparsers = parser.add_subparsers()

    ####################################################################################################################
    peek_parser = subparsers.add_parser(
        "peek", help="Peek at contents of memory",
        description="The peek function allows values to be read from memory. Reads are actioned as bytes by default, "
                    "unless either the --word or --long option is supplied. --alt may be supplied to cause byte values "
                    "to be read from alternate memory locations, which is useful for interfacing with 8-bit devices "
                    "which are connected to one half of a 16-bit data bus."
    )
    peek_parser.set_defaults(which="peek")
    peek_parser.add_argument(
        "-a",
        dest="address", type=number, default=None, required=True,
        help="The address to start reading from. Min 0, max 0xFFFFFFFF."
    )
    peek_parser.add_argument(
        "-l",
        dest="length", type=number, default=None, required=True,
        help="How many bytes to read. Min 1, max 4294967295."
    )
    peek_size_group = peek_parser.add_mutually_exclusive_group()
    peek_size_group.add_argument(
        "--word",
        dest="word_flag", action="store_true",
        help="Read using WORD bus cycles"
    )
    peek_size_group.add_argument(
        "--long",
        dest="long_flag", action="store_true",
        help="Read using LONG bus cycles"
    )
    peek_size_group.add_argument(
        "--alt",
        dest="alt_flag", action="store_true",
        help="Read from alternate bytes from the starting address"
    )
    peek_parser.add_argument(
        "--block",
        dest="block_flag", action="store_true",
        help="Perform a read non-sequentially (pointer does not increase)"
    )
    peek_parser.add_argument(
        "file", type=str, nargs="?", default=None,
        help="Read the contents into a file. If not specified, the tool will provide a hex dump."
    )

    ####################################################################################################################
    poke_parser = subparsers.add_parser(
        "poke", help="Poke values into memory",
        description="The poke function allows values to be set in memory. Writes are actioned as bytes by default, "
                    "unless either the --word or --long option is supplied. --alt may be supplied to cause byte values "
                    "to be written to alternate memory locations, which is useful for interfacing with 8-bit devices "
                    "which are connected to one half of a 16-bit data bus. "
                    ""
                    "Poke differs from load in that poke allows the user to specify the values as part of the command, "
                    "while load takes in a file."
    )
    poke_parser.set_defaults(which="poke")
    poke_parser.add_argument(
        "-a",
        dest="address", type=number, default=None, required=True,
        help="The address to start writing from. Min 0, max 0xFFFFFFFF."
    )
    poke_size_group = poke_parser.add_mutually_exclusive_group()
    poke_size_group.add_argument(
        "--word",
        dest="word_flag", action="store_true",
        help="Write using WORD bus cycles"
    )
    poke_size_group.add_argument(
        "--long",
        dest="long_flag", action="store_true",
        help="Write using LONG bus cycles"
    )
    poke_size_group.add_argument(
        "--alt",
        dest="alt_flag", action="store_true",
        help="Write to alternate bytes from the starting address"
    )
    poke_parser.add_argument(
        "--block",
        dest="block_flag", action="store_true",
        help="Perform a write non-sequentially (pointer does not increase)"
    )
    poke_run_group = poke_parser.add_mutually_exclusive_group()
    poke_run_group.add_argument(
        "-b",
        dest="boot", type=number, default=None,
        help="After writing, boot from the specified address, treating the first two LONGs as initial stack pointer "
             "and program counter"
    )
    poke_run_group.add_argument(
        "-j",
        dest="jump", type=number, default=None,
        help="After writing, perform a JMP instruction to the specified address"
    )
    poke_run_group.add_argument(
        "-e",
        dest="exec", type=number, default=None,
        help="After writing, perform a JSR instruction to the specified address"
    )
    poke_parser.add_argument(
        "--console",
        dest="console_flag", action="store_true",
        help="After writing, wait and print any characters that are received back from the board via the serial port"
    )
    poke_parser.add_argument(
        "data", type=str, nargs="+", default=None,
        help="The data to be written to memory, specified in hexadecimal format. Data will be left padded with zeroes "
             "to suit the data type (byte, word, long)."
    )

    ####################################################################################################################
    load_parser = subparsers.add_parser(
        "load", help="Load file contents into memory",
        description="The load function allows a files contents to be written to memory. Writes are action as as bytes "
                    "by default, unless either the --word or --long option is supplied. --alt may be supplied to cause "
                    "byte values to be written to alternate memory locations, which is useful for interfacing with "
                    "8-bit devices which are connected to one half of a 16-bit data bus. "
                    ""
                    "Load differs from poke in that poke allows the user to specify the values as part of the command, "
                    "while load takes in a file."
    )
    load_parser.set_defaults(which="load")
    load_parser.add_argument(
        "-a",
        dest="address", type=number, default=None, required=True,
        help="The address to start writing from. Min 0, max 0xFFFFFFFF."
    )
    load_size_group = load_parser.add_mutually_exclusive_group()
    load_size_group.add_argument(
        "--word",
        dest="word_flag", action="store_true",
        help="Write using WORD bus cycles"
    )
    load_size_group.add_argument(
        "--long",
        dest="long_flag", action="store_true",
        help="Write using LONG bus cycles"
    )
    load_size_group.add_argument(
        "--alt",
        dest="alt_flag", action="store_true",
        help="Write to alternate bytes from the starting address"
    )
    load_parser.add_argument(
        "--block",
        dest="block_flag", action="store_true",
        help="Perform a write non-sequentially (pointer does not increase)"
    )
    load_run_group = load_parser.add_mutually_exclusive_group()
    load_run_group.add_argument(
        "-b",
        dest="boot", type=number, default=None,
        help="After writing, boot from the specified address, treating the first two LONGs as initial stack pointer "
             "and program counter"
    )
    load_run_group.add_argument(
        "-j",
        dest="jump", type=number, default=None,
        help="After writing, perform a JMP instruction to the specified address"
    )
    load_run_group.add_argument(
        "-e",
        dest="exec", type=number, default=None,
        help="After writing, perform a JSR instruction to the specified address"
    )
    load_parser.add_argument(
        "--console",
        dest="console_flag", action="store_true",
        help="After writing, wait and print any characters that are received back from the board via the serial port"
    )
    load_parser.add_argument(
        "file", type=str, nargs=1, default=None,
        help="The file whose contents are to be written to memory"
    )

    ####################################################################################################################
    run_parser = subparsers.add_parser(
        "run", help="Run code using a number of different methods",
        description="Run allows execution to be transferred to an address using a number of different methods."
    )
    run_parser.set_defaults(which="run")
    run_group = run_parser.add_mutually_exclusive_group()
    run_group.add_argument(
        "-b",
        dest="boot", type=number, default=None,
        help="Simulate a boot from the specified address, treating the first two LONGs as initial stack pointer and "
             "program counter"
    )
    run_group.add_argument(
        "-j",
        dest="jump", type=number, default=None,
        help="Perform a JMP instruction to the specified address"
    )
    run_group.add_argument(
        "-e",
        dest="exec", type=number, default=None,
        help="Perform a JSR instruction to the specified address"
    )
    run_parser.add_argument(
        "--console",
        dest="console_flag", action="store_true",
        help="Wait and print any characters that are received back from the board via the serial port"
    )
    ####################################################################################################################

    flash_parser = subparsers.add_parser(
        "flash", help="Perform operations on flash memory devices",
        description="The flash function provides utilities for working with flash memory devices. It allows flash "
                    "memory devices to be identified, erased, and programmed while they are in the system. "
                    ""
                    "If neither --16bit or --alt are specified, the flash memory is accessed as an 8-bit device which "
                    "is assumed to have an A0 address signal (fully linear). --alt works in conjunction with the LSb "
                    "of the address to appropriately address 8-bit flash memories on either half of the data bus. "
                    ""
                    "--16bit causes the flash memory to be accessed using 16-bit operations."
    )
    flash_parser.set_defaults(which="flash")
    flash_parser.add_argument(
        "-a",
        dest="address", type=number, default=None, required=True,
        help="The base address of the flash memory device. Min 0, max 0xFFFFFFFF."
    )
    flash_bus_op_group = flash_parser.add_mutually_exclusive_group()
    flash_bus_op_group.add_argument(
        "--16bit",
        dest="sixteen_flag", action="store_true",
        help="The target flash memory device operates in 16-bit mode"
    )
    flash_bus_op_group.add_argument(
        "--alt",
        dest="alt_flag", action="store_true",
        help="The target flash memory device operates in 8-bit mode on even or odd addresses, determined by the LSb of "
             "the address"
    )
    flash_op_group = flash_parser.add_mutually_exclusive_group()
    flash_op_group.add_argument(
        "--identify",
        dest="ident_op", action="store_true",
        help="Attempts to read the electronic signature using the AUTO SELECT command method"
    )
    flash_op_group.add_argument(
        "--erase",
        dest="erase_op", action="store_true",
        help="Erase a (entire) flash memory device using the CHIP ERASE command method"
    )
    flash_op_group.add_argument(
        "--prog",
        dest="prog_op", action="store_true",
        help="Program a flash memory device from a file"
    )
    flash_parser.add_argument(
        "--data",
        dest="data_flag", action="store_true",
        help="The data to be programmed is supplied as part of the command in place of a filename"
    )
    flash_parser.add_argument(
        "file", type=str, nargs="*", default=None,
        help="The file whose contents are to be programmed into the flash memory, or literal data if the --data option "
             "is specified. Literal data is specified in hexadecimal format. Data will be left padded with zeroes to "
             "suit the size of the flash memory being operated on (byte or word, based on whether the --16bit option "
             "is specified)."
    )
    ####################################################################################################################

    # Flags start all unset and will be set as appropriate
    flags = 0

    args = parser.parse_args()

    if args.which is not None:
        if args.which == "peek":
            if args.length < 1 or args.length > 4294967295:
                print("ERROR: Length out of valid range 1-4294967295")

                return

            if args.word_flag:
                if args.length % 2:
                    print("ERROR: When reading or writing as WORD, the length must be a multiple of 2")

                    return

            if args.long_flag:
                if args.length % 4:
                    print("ERROR: When reading or writing as LONG, the length must be a multiple of 4")

                    return

        if args.which == "load":
            # Load the contents of the file
            length = os.stat(args.file[0]).st_size

            if args.word_flag:
                if length % 2:
                    print("ERROR: When reading or writing as WORD, the length must be a multiple of 2")

                    return

            if args.long_flag:
                if length % 4:
                    print("ERROR: When reading or writing as LONG, the length must be a multiple of 4")

                    return

            with open(args.file[0], "r+b") as file:
                data_wr = file.read(length)

            # Convert bytes to hex string
            data_str = ""

            for data in data_wr:
                data_str += f"{data:02x}"

            # Morph into a poke command
            load_parser.set_defaults(data=[data_str])
            load_parser.set_defaults(which="poke")
            args = parser.parse_args()

        if args.which == "flash":
            if args.prog_op:
                if args.file is None:
                    if args.data_flag:
                        print("ERROR: When programming a flash memory device with the --data option, you need to "
                              "specify the data to be programmed as part of the command (in place of a filename")
                    else:
                        print("ERROR: When programming a flash memory device, you need to specify a file to be "
                              "programmed")

                    return

                if args.data_flag:
                    # Use the file argument as a source of data
                    data_wr = "".join(args.file)

                    # Left pad with zeroes
                    if args.sixteen_flag:
                        if len(data_wr) % 4:
                            data_wr = "0" * (4 - len(data_wr) % 4) + data_wr
                    else:
                        if len(data_wr) % 2:
                            data_wr = "0" * (2 - len(data_wr) % 2) + data_wr

                    # Convert to bytes for transmission
                    data_wr = convert_hex_to_bytes(data_wr)
                else:
                    # Load the contents of the file
                    length = os.stat(args.file[0]).st_size

                    # The file argument is actually a file
                    with open(args.file[0], "r+b") as file:
                        data_wr = file.read(length)

                    # For 16-bit operations, if the length of the data is odd, append 0xFF to make it even
                    if args.sixteen_flag:
                        if length & 0x1:
                            data_wr += bytes([0xFF])

            # 16-bit flash memories should be addressed on word boundaries
            if args.sixteen_flag:
                args.address &= 0xFFFFFFFE

        # Set flags
        if args.alt_flag:
            flags |= Flags.ALT

        if args.block_flag:
            flags |= Flags.BLOCK

        if args.sixteen_flag:
            flags |= Flags.SIXTEEN

        if args.alt_flag and args.block_flag:
            print("WARNING: --alt and --block together are incompatible - --block will be ignored")

        # Sanity check common arguments
        if args.word_flag or args.long_flag:
            if args.address & 0x1:
                print("ERROR: When reading or writing as WORD or LONG, addresses must be even")

                return

        if args.which != "run":
            if args.address < 0 or args.address > 0xFFFFFFFF:
                print("ERROR: Address out of valid range 0-0xFFFFFFFF")

                return

    port = os.getenv(PORT_VAR)
    baud = os.getenv(BAUD_VAR)

    if port is None or baud is None:
        print(
            f"ERROR: \"{PORT_VAR}\" or \"{BAUD_VAR}\" environment variables are not set. These variables should be "
            f"set to specify which device (serial port) and speed to use when communicating with the bootloader."
        )

        return

    # Establish connection with bootloader
    ser = Serial(
        port,
        baudrate=baud,
        timeout=1
    )

    if ser.in_waiting > 0:
        ser.read(size=ser.in_waiting)

    if args.which in ("peek", "poke", "flash") or args.which == "run" and args.boot is False and args.jump is False and args.exec is False:
        print("Waiting for bootloader availability: ", end="", flush=True)

        if check_bootloader_available(ser) is True:
            print("OK")
        else:
            print("Bootloader did not respond")

            return

    if args.which is None:
        # Just ping the bootloader and then return
        print("Use --help to get more information about how to use this utility")

        return

    start = time.time()

    if args.which == "peek":
        peek(ser, flags, args.address, args.length, args.word_flag, args.long_flag, args.file)
    elif args.which == "poke":
        poke(ser, flags, args.address, args.word_flag, args.long_flag, "".join(args.data))

        if args.boot is not None or args.jump is not None or args.exec is not None:
            # Morph into a run command. We could have got here via load or poke, so set which to "run" in both of them.
            poke_parser.set_defaults(which="run")
            load_parser.set_defaults(which="run")
            args = parser.parse_args()
    elif args.which == "flash":
        if args.ident_op is True:
            flash_id(ser, flags, args.address)
        elif args.erase_op is True:
            flash_chip_erase(ser, flags, args.address)
        elif args.prog_op is True:
            flash_program(ser, flags, args.address, data_wr)

        if args.boot is not None or args.jump is not None or args.exec is not None:
            # Morph into a run command
            flash_parser.set_defaults(which="run")
            args = parser.parse_args()

    if args.which == "run":
        if args.boot is not None:
            boot(ser, args.boot)
        elif args.jump is not None:
            jmp(ser, args.jump)
        elif args.exec is not None:
            jsr(ser, args.exec)

    duration = time.time() - start

    print("Done in %.3fs" % duration)

    if args.which == "run":
        if args.console_flag is True:
            # Wait and print any characters that are received from the board
            print()
            print(">>> Console (RX only) =========================================================")

            while True:
                try:
                    char = int.from_bytes(ser.read(size=1), "little")

                    if char in [0x0D]:
                        print(chr(char), flush=True)

                    if 0x20 <= char <= 0x7F:
                        print(chr(char), end="", flush=True)
                except KeyboardInterrupt:
                    # Allow us to exit on Ctrl-C
                    print()

                    break

    # Done
    ser.close()


if __name__ == "__main__":
    main()
