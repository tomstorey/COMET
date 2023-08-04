# Create a combined, checksummed ROM-devicetree image ready for programming
#
# The layout of the image will look as follows:
#
# Highest address: checksum (long)
#                  8KB - 4 bytes (devicetree area)
#                  (blank space filled with all ones)
#  Lowest address: n bytes (application code)
#
# The size of the devicetree area defaults to the highest 8KB of the image, but
# the size may be adjusted with the dtsz commandline option. The size must be
# specified as a multiple of 2KB and must be a minimum of 8KB.
#
# The checksum is a long value which, when added to the sum of all prior long
# values, results in a final value of 0.

import struct
import argparse

DEFAULT_DEVTREE_SIZE = 8
DEFAULT_ROM_SIZE = 512

def main() -> None:
    # Parse command line options
    parser = argparse.ArgumentParser(description="Create a combined, checksummed ROM-devicetree "
                                                 "image ready for programming")
    parser.add_argument("-d", "--dtsz", dest="devtree_size", default=DEFAULT_DEVTREE_SIZE, type=int,
                        help= "The number of kilobytes to set aside at the top of the resulting "
                             f"image for the devicetree blob (default {DEFAULT_DEVTREE_SIZE})")
    parser.add_argument("-s", "--romsz", dest="rom_size", default=DEFAULT_ROM_SIZE, type=int,
                        help=f"The size of the resulting image in kilobytes (default {DEFAULT_ROM_SIZE})")
    parser.add_argument("-i", "--input", dest="input_bin", required=True, help="Filename of input application binary")
    parser.add_argument("-b", "--blob", dest="input_blob", required=True, help="Filename of input devicetree blob")
    parser.add_argument("-o", "--output", dest="output_img", required=True, help="Filename of output programming image")
    args = parser.parse_args()

    dtb_size_bytes = (args.devtree_size * 1024) - 4
    rom_size_bytes = args.rom_size * 1024

    # Sanity check arguments
    if args.devtree_size % 2 != 0 or args.devtree_size < 8:
        print("Devicetree blob size must be a multiple of 2KB and a minimum of 8KB")

        return 1

    # Load input files
    input_bin = None
    input_blob = None

    print("Reading input application binary ...")
    with open(args.input_bin, "rb") as f:
        input_bin = f.read()

    print("Reading input devicetree blob ...")
    with open(args.input_blob, "rb") as f:
        input_blob = f.read()
    
    # Make sure sizes are workable
    if len(input_bin) > (rom_size_bytes - (dtb_size_bytes + 4)):
        print("Input application binary is too big to fit")

        return 1
    
    if len(input_blob) > dtb_size_bytes:
        print("Input devicetree blob is too big to fit")

        return 1

    with open(args.output_img, "w+b") as f:
        print("Writing combined image file ...")

        # First write in the application binary
        f.seek(0)
        f.write(input_bin)

        # Then write in filler space before the devicetree blob
        filler_bytes = rom_size_bytes - len(input_bin) - dtb_size_bytes - 4
        f.write(bytes([0xFF] * filler_bytes))

        # Then write in the devicetree blob
        f.write(input_blob)

        # Then write in filler space before the checksum
        filler_bytes = dtb_size_bytes - len(input_blob)
        f.write(bytes([0xFF] * filler_bytes))

        # Now calculate the checksum value
        print("Calculating checksum ... ", end="")

        iters = int((rom_size_bytes / 4) - 1)
        cksum = 0

        f.seek(0)

        while iters > 0:
            l = struct.unpack(">L", f.read(4))[0]

            cksum -= l
            cksum &= 0xFFFFFFFF
            
            iters -= 1

        # Write checksum to end of file
        f.write(struct.pack(">L", cksum))

        print(f"{cksum:08X}")

        # Verify the checksum
        print("Verifying checksum ... ", end="")

        iters = int(rom_size_bytes / 4)
        total = 0

        f.seek(0)

        while iters > 0:
            l = struct.unpack(">L", f.read(4))[0]

            total += l
            total &= 0xFFFFFFFF
            
            iters -= 1

        # Print result of checksum sequence
        if total == 0:
            print("OK")
            print("Image file is ready for programming")
        else:
            print(f"BAD ({total:08X})")
            print("Image file is invalid")



if __name__ == "__main__":
    main()
