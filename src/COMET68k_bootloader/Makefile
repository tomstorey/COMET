# List all of the object files that will be combined into your final binary
# in the OBJ variable.
#
# For example, if you have the following source files
#
#   main.c
#   user.c
#   driver.s
#
# then your OBJ list would be
#
#   main.o user.o driver.o
#
# The compiler will automatically choose the correct source file (.c, .s etc)
# according to the object file (.o) to be created.

CPU=68000

# PREFIX=m68k-linux-gnu
PREFIX=m68k-eabi-elf

OBJ=main.o

# Dont modify below this line (unless you know what youre doing).

CC=$(PREFIX)-gcc
AS=$(PREFIX)-as
LD=$(PREFIX)-ld
OBJCOPY=$(PREFIX)-objcopy
OBJDUMP=$(PREFIX)-objdump

CFLAGS=-m$(CPU) -Wall -g -static -I../../../m68k_bare_metal/include -I. -msoft-float -MMD -MP -O
LFLAGS=--script=platform.ld -L../../../m68k_bare_metal/libmetal -lmetal-68000
AFLAGS=-m$(CPU) -Wall -c -g

SRC=$(wildcard *.c)
DEP=$(SRC:%.c=%.d)

%.o: %.c
	$(CC) $(CFLAGS) -m$(CPU) -c -o $@ $<

%.o: %.S
	$(CC) $(CFLAGS) -m$(CPU) -c $<

%.o: %.s
	$(CC) $(CFLAGS) -m$(CPU) -c $<

bmbinary: $(OBJ)
	$(LD) -o $@ $(OBJ) $(LFLAGS)

-include $(DEP)

all: crt bmbinary rom

crt: crt0.o

clean:
	rm -f bmbinary bmbinary.rom bmbinary.srec $(OBJ) $(DEP)

rom:
	$(OBJCOPY) -O binary bmbinary bmbinary.rom
	$(OBJCOPY) -O srec bmbinary bmbinary.srec
	python3 make_image.py -s512 -ibmbinary.rom -b../devicetree/COMET68k.dtb -obootloader.bin

dump:
	$(OBJDUMP) -mm68k:$(CPU) -belf32-m68k -st -j.evt bmbinary
	$(OBJDUMP) -mm68k:$(CPU) -belf32-m68k -dt -j.text bmbinary
	$(OBJDUMP) -mm68k:$(CPU) -belf32-m68k -st -j.rodata -j.data -j.bss -j.heap -j.stack bmbinary

dumps:
	$(OBJDUMP) -mm68k:$(CPU) -belf32-m68k -st -j.evt bmbinary
	$(OBJDUMP) -mm68k:$(CPU) -belf32-m68k -St -j.text bmbinary
	$(OBJDUMP) -mm68k:$(CPU) -belf32-m68k -st -j.rodata -j.data -j.bss -j.heap -j.stack bmbinary

hexdump:
	hexdump -C bmbinary.rom
