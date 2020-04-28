build:
	@dune build @install

clean:
	@dune clean

test-all:
	SIHL_ENV=test DATABASE=mariadb dune runtest --force --no-buffer
	SIHL_ENV=test DATABASE=postgres dune runtest --force --no-buffer

test:
	SIHL_ENV=test DATABASE=postgres dune runtest --no-buffer -w
