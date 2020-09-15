.PHONY: all test clean

build:
	opam exec -- dune build

clean:
	opam exec -- dune clean

test:
	SIHL_ENV=test opam exec -- dune test

test-slow:
	SIHL_ENV=test opam exec -- dune build @runtest-all --force test

doc:
	opam exec -- dune build @doc
