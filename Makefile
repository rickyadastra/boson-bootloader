.PHONY: build

build:
	@c3c build boson --trust=full

run:
	@c3c build run --trust=full

clear:
	@c3c clean
	@rm -rf ./build
