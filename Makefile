build:
	@dune build @install

clean:
	@dune clean

test-mariadb:
	SIHL_ENV=test dune runtest --force --no-buffer test/test-mariadb

test-postgresql:
	SIHL_ENV=test dune runtest --force --no-buffer test/test-postgresql

test-dev:
	SIHL_ENV=test DATABASE=postgres dune runtest --no-buffer -w test/test-unit test/test-memory

test-all:
	SIHL_ENV=test dune runtest --force --no-buffer test
