#
#    Makefile for Tiny AVR Projects (100% assembly, no startup/avr-libc)
#
#    Copyright (C) 1998-2015  Gilles Gameiro / Birdland Audio
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#


#---------------------------
#  Give the Project a name
#---------------------------
PROJECT = bavmon


#-------------------------------------------------------------
# Define Both Program and Libraries ASM and C/C++ input files
#-------------------------------------------------------------
ASRC	= startt4.asm bios.asm main.asm
ALIBS  =


#------------------------------------------------------------
#  Define what the project is and what the source files are
#------------------------------------------------------------
MCU     = attiny4
DUDEMCU	= t4
CLOCK   = 8000000
BUILDIR = _build
ULIBDIR = ../_atmel.libs


#tiny4 fuse             RESVD    RESVD    RESVD    RESVD    RESVD    CLKOUT   WDTON   DISRESET          
#                         1        1        1        1        1        1        1        0
FUSE = 0xfe



#----------------------------------------
#  Define avr-gcc environment if needed
#----------------------------------------
AVRDIR  = /usr/local/CrossPack-AVR
AVRBIN  = $(AVRDIR)/bin
LIBDIR  = $(AVRDIR)/lib
INCLUDE = -I . -I $(ULIBDIR)/inc

CC      = $(AVRBIN)/avr-gcc
ASM     = $(AVRBIN)/avr-as
#ASM     = $(AVRBIN)/avr-as -alms -I $(AVRDIR)/avr/include
#ASM     = $(AVRBIN)/avr-gcc -x assembler-with-cpp
AFLAGS  = -gstabs -mmcu=$(MCU)
LFLAGS  = -nostartfiles -nodefaultlibs -Wl,-Map=$(BUILDIR)/$(PROJECT).map,--cref -DF_CPU=$(CLOCK) -mmcu=$(MCU)


# CCFLAGS Cheat sheet
#  -g:        generate debugging information (for GDB, or for COFF conversion)
#  -O*:       optimization level
#  -f...:     tuning, see gcc manual and avr-libc documentation
#  -Wall...:  warning level
#  -Wa,...:   tell GCC to pass this to the assembler.
#    -ahlms:  create assembler listing





#---------------------------------------------
#  Everything here after needs not be edited
#---------------------------------------------

OBJS	= $(foreach file,$(ASRC:.asm=.o) $(ALIBS:.asm=.alib.o), $(BUILDIR)/$(file))


# Define make targets
all: $(BUILDIR)/$(PROJECT).elf $(BUILDIR)/$(PROJECT).hex

fuses:
	$(AVRBIN)/avrdude -c avrispmkII -P usb -p $(DUDEMCU) -D -u -U fuse:w:$(FUSE):m
#	$(AVRBIN)/avrdude -c avrispmkII -P usb -p $(DUDEMCU) -D -u -U efuse:w:$(EFUSE):m -U hfuse:w:$(HFUSE):m -U lfuse:w:$(LFUSE):m
	

flash: $(BUILDIR)/$(PROJECT).hex
	$(AVRBIN)/avrdude -c avrispmkII -P usb -p $(DUDEMCU) -U flash:w:$(BUILDIR)/$(PROJECT).hex:i


inspect:
	$(AVRBIN)/avrdude -c avrispmkII -P usb -p $(DUDEMCU) -t
	


clean:
	clear
	rm -f $(OBJS)
	rm -f $(OBJS:.o=.lst)
	rm -f $(BUILDIR)/*


view: $(BUILDIR)/$(PROJECT).elf
	$(AVRBIN)/avr-objdump -S $(BUILDIR)/$(PROJECT).elf | less



# Declare ASM / Object Rules
$(BUILDIR)/%.o : %.asm
	$(ASM) -c $(AFLAGS) $(INCLUDE) $< -o $@
#	$(ASM) -c $(AFLAGS) $(INCLUDE) $< -alms $(@:.o=.lst) -o $@
	
$(BUILDDIR)/%.alib.o : $(ULIBDIR)/lib/%.asm
	$(ASM) $(AFLAGS) $(INCLUDE) $< -o $@


$(BUILDIR)/$(PROJECT).elf: $(OBJS)
	$(CC) $(OBJS) $(LIBS) $(LFLAGS) -o $@

$(BUILDIR)/$(PROJECT).hex: $(BUILDIR)/$(PROJECT).elf
	$(AVRBIN)/avr-objcopy -j .text -j .data -O ihex $< $@


#$(AVRBIN)/avr-objcopy -j .eeprom --set-section-flags=.eeprom="alloc,load" -O ihex $< $(@:.hex=.eep)
#$(PROJECT).obj: $(PROJECT).elf
#	$(AVRBIN)/avr-objcopy -O avrobj $< $@

#$(PROJECT).rom: $(PROJECT).elf
#	$(AVRBIN)/avr-objcopy -O srec $< $@
#$(AVRBIN)/avr-objcopy -j .eeprom --set-section-flags=.eeprom="alloc,load" -O srec $< $(@:.rom=.eep)



# Gilles Cheat Sheet
# $*  Stem (typically file without suffix). Eg: if target dir/a.foo.b matched with pattern a.%.b, $* is dir/foo
# $@  The current target
# $<  The Implied source in a suffix rule
# $?  All pre-requisites newer than the target
# $^  All identified pre-requisites
# $+  Same as $^ but lists duplicates in the order found
# $|  The names of all the order-only pre-requisites.
