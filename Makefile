build:
	@dune build @install

clean:
	@dune clean

test-mariadb:
	SIHL_ENV=test dune runtest --force test/test-mariadb

test-postgresql:
	SIHL_ENV=test dune runtest --force test/test-postgresql

test-dev:
	SIHL_ENV=test DATABASE=postgres dune runtest -w test/test-unit test/test-memory

test-all:
	SIHL_ENV=test dune runtest --force test

doc:
	dune build @doc
	cp -f docs/odoc.css _build/default/_doc/_html/odoc.css
