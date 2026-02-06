APP=otoge
SRC=src/otoge.cr
BIN=bin/$(APP)
CRFLAGS=-Dpreview_mt -Dexecution_context
release?=1d

.DEFAULT_GOAL := build

ifeq ($(release),1)
	CRFLAGS+=--release
endif

.PHONY: deps run build clean melodica build-melodica

deps:
	shards

run: deps
	crystal run $(SRC) $(CRFLAGS)

build: deps
	mkdir -p bin
	crystal build $(SRC) -o $(BIN) $(CRFLAGS)
	crystal build src/melodica.cr -o bin/melodica $(CRFLAGS)

melodica: deps
	crystal run src/melodica.cr $(CRFLAGS)

clean:
	rm -rf bin
