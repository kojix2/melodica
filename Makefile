APP=otoge
SRC=src/otoge.cr
BIN=bin/$(APP)
CRFLAGS=-Dpreview_mt -Dexecution_context
release?=0

ifeq ($(release),1)
	CRFLAGS+=--release
endif

.PHONY: deps run build clean

deps:
	shards

run: deps
	crystal run $(SRC) $(CRFLAGS)

build: deps
	mkdir -p bin
	crystal build $(SRC) -o $(BIN) $(CRFLAGS)

clean:
	rm -rf bin
