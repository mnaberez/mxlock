PROJECT=mxlock
MCU=t414
ISPFLAGS=-c atmelice_updi

PROJECT_FLASH  = $(PROJECT)_$(MCU)_flash
PROJECT_FUSES  = $(PROJECT)_$(MCU)_fuses
PROJECT_EEPROM = $(PROJECT)_$(MCU)_eeprom

ifeq ($(MCU),t214)
DEFSFILE=tn214def.asm
else ifeq ($(MCU),t414)
DEFSFILE=tn414def.asm
else ifeq ($(MCU),t814)
DEFSFILE=tn814def.asm
else
$(error Unrecognized MCU value)
endif

all: $(PROJECT_FLASH).hex $(PROJECT_FUSES).hex $(PROJECT_EEPROM).hex

clean:
	rm -f $(PROJECT)_*_flash.*
	rm -f $(PROJECT)_*_fuses.*
	rm -f $(PROJECT)_*_eeprom.*

program: $(PROJECT_FLASH).hex $(PROJECT_FUSES).hex
	avrdude $(ISPFLAGS) -p $(MCU) -e -U flash:w:$(PROJECT_FLASH).hex:i -U fuses:w:$(PROJECT_FUSES).hex:i -U eeprom:w:$(PROJECT_EEPROM).hex:i

$(PROJECT_FLASH).hex: main.asm
	# add -i ".list" before -i ".include '$(DEFSFILE)'" to see it in the listing output
	asavr -l -p -w -i ".include '$(DEFSFILE)'" -o+$(PROJECT_FLASH) main.asm
	aslink -i $(PROJECT_FLASH)
	rm $(PROJECT_FLASH).hlr $(PROJECT_FLASH).rel

$(PROJECT_FUSES).hex: fuses.asm
	asavr -l -p -w -i ".include '$(DEFSFILE)'" -o+$(PROJECT_FUSES) fuses.asm
	aslink -i $(PROJECT_FUSES)
	rm $(PROJECT_FUSES).hlr $(PROJECT_FUSES).rel

$(PROJECT_EEPROM).hex: eeprom.asm
	asavr -l -p -w -i ".include '$(DEFSFILE)'" -o+$(PROJECT_EEPROM) eeprom.asm
	aslink -i $(PROJECT_EEPROM)
	rm $(PROJECT_EEPROM).hlr $(PROJECT_EEPROM).rel
