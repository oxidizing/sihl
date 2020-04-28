build:
	@dune build @install

clean:
	@dune clean

test:
	DATABASE=mariadb dune runtest --force --no-buffer
	DATABASE=postgres dune runtest --force --no-buffer
