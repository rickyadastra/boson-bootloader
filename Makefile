.PHONY: build

C3C 	:= /mnt/e/OSDev/c3c/build/c3c
FLAGS 	:= --trust=full --warn-builtin=no

build:
	@${C3C} build boson ${FLAGS}

run:
	@${C3C} build run ${FLAGS}

clear:
	@${C3C} clean
	@rm -rf ./build
