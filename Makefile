build:
	@dune build @install

clean:
	@dune clean

test:
	@dune runtest --force
