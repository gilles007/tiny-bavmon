# Generic Makefile for Tiny AVR Projects (assembly only to avoid avr-libc)
#
# (c) Copyright Gilles Gameiro 1998
# (c) Copyright Birdland Audio 2010~2014
# You may modify and reuse this file as long as the Copyrights above remain listed above. 


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
DUDEMCU	= t4
MCU     = attiny4
CLOCK   = 8000000
BUILDIR = _build
ULIBDIR = ../_atmel.libs


#mega168 low fuse      CLKDIV8   CKOUT    SUT1     SUT0    CKSEL3   CKSEL2   CKSEL1   CKSEL0
#                         1        1        1        0        0        0        1        0        
LFUSE = 0xe2  # Master Clock no divide, Clock out disabled, default internal 128K setup, Internal RC Clock

#mega168 high fuse      RSTDIS   DBWEN    SPIEN    WDTON    EESAVE    BOD2     BOD1     BOD0
#                         1        1        0        1        1        1        1        1
HFUSE = 0xdf  # Reset pin disabled, debugWire disabled, SPI programming enabled, Erase EE on program, Disable Brown Out detection

#mega168 ext fuse       RESVD    RESVD    RESVD    RESVD    RESVD   BOOTSZ1  BOOTSZ0  BOOTRST          
#                         1        1        1        1        1        1        1        1
EFUSE = 0xff  # Smalest boot sector, Boot Reset set to address 0x000




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
AFLAGS  = -gstabs -mmcu=$(MCU) -I.
LFLAGS  = -Wl,-Map=$(BUILDIR)/$(PROJECT).map,--cref -DF_CPU=$(CLOCK) -mmcu=$(MCU)


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

OBJS	= $(foreach file,$(ASRC:.asm=.asm.o) $(ALIBS:.asm=.alib.o), $(BUILDIR)/$(file))


# Define make targets
all: $(BUILDIR)/$(PROJECT).elf $(BUILDIR)/$(PROJECT).hex

fuses:
	$(AVRBIN)/avrdude -c avrispmkII -P usb -p $(DUDEMCU) -D -u -U efuse:w:$(EFUSE):m -U hfuse:w:$(HFUSE):m -U lfuse:w:$(LFUSE):m


flash: $(BUILDIR)/$(PROJECT).hex
	$(AVRBIN)/avrdude -c avrispmkII -P usb -p $(DUDEMCU) -U flash:w:$(BUILDIR)/$(PROJECT).hex:i


inspect:
	$(AVRBIN)/avrdude -c avrispmkII -P usb -p $(DUDEMCU) -t
	


clean:
	clear
	rm -f $(OBJS)
	rm -f $(OBJS:.o=.lst)
	rm -f $(BUILDIR)/$(PROJECT).map
	rm -f $(BUILDIR)/$(PROJECT).elf
	rm -f $(BUILDIR)/$(PROJECT).obj
	rm -f $(BUILDIR)/$(PROJECT).eep
	rm -f $(BUILDIR)/$(PROJECT).elf
	rm -f $(BUILDIR)/$(PROJECT).avd
	rm -f $(BUILDIR)/$(PROJECT).rom
	rm -f $(BUILDIR)/$(PROJECT).hex




# Declare ASM / Object Rules
$(BUILDIR)/%.asm.o : %.asm
	$(ASM) -c $(AFLAGS) $(INCLUDE) $< -o $@
	
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
