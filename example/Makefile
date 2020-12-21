.PHONY: all test clean

build:
	opam exec -- dune build

clean:
	opam exec -- dune clean

test:
	opam exec -- dune test

test-slow:
	opam exec -- dune build @runtest-all --force test
