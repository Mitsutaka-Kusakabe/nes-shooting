ROM     := game.nes
BUILD   := build

SRC := $(wildcard src/*.s) $(wildcard assets/*.s)

.PHONY: all clean

all: $(ROM)

$(ROM): $(BUILD)/main.o nes.cfg
	ld65 -C nes.cfg --dbgfile $(BUILD)/dbg.txt -o $@ $(BUILD)/main.o
	@ls -l $@

$(BUILD)/main.o: $(SRC) | $(BUILD)
	ca65 -g src/main.s -o $@

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD) $(ROM)
