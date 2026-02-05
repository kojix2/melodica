APP=otoge
SRC=src/otoge.cr
BIN=bin/$(APP)
CRFLAGS=-Dpreview_mt -Dexecution_context

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
