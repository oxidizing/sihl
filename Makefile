.PHONY: all test clean

build:
	@dune build @install

clean:
	@dune clean

test:
	SIHL_ENV=test dune test

test-slow:
	SIHL_ENV=test dune build @runtest-all --force test

doc:
	dune build @doc
	cp -f docs/odoc.css _build/default/_doc/_html/odoc.css
