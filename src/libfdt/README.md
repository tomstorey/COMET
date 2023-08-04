# libfdt
`libfdt` is a library which can be used to parse and manipulate devicetree blobs.

It needs to be compiled prior to use, but this is a simple process.

Modify `Makefile` and adjust it for the type of CPU the library is being compiled for. Then simply run `make all` from the command line. The result is a file called `libfdt-{CPUTYPE}.a`, which is the library compiled for a particular type of CPU.

The library can then be used in your projects where you need to interact with devicetree blobs - just include it via your projects own `Makefile`.

## Notes
Compilation of `libfdt` assumes you are using my Motorola 68000 toolchain (https://github.com/tomstorey/m68k_bare_metal) and that it is located in the same parent directory as the COMET repository, that is to suggest something like the following:

> ~/git/m68k_bare_metal/...  
~/git/COMET/...

For other toolchains you may need to make modifications to the `Makefile` to adjust for the changes to compiler binary names etc.

## License
The original source of this code is: https://github.com/kernkonzept/libfdt/tree/master/lib/contrib

I have made no modifications other than to pare it down to a more minimal form for compilation for my own uses. The original authors maintain all rights.
