.PHONY: build test test-memory test-mariadb test-postgresql test-http

build:
	opam exec -- dune build

clean:
	opam exec -- dune clean

test-unit: build
	SIHL_ENV=test opam exec -- dune test

test-memory: build
	SIHL_ENV=test ./_build/default/sihl-email/test/template.exe
	SIHL_ENV=test ./_build/default/sihl-web/test/bearer_token.exe
	SIHL_ENV=test ./_build/default/sihl-token/test/jwt_inmemory.exe
	SIHL_ENV=test ./_build/default/sihl-queue/test/queue_memory.exe

test-mariadb: build
	SIHL_ENV=test ./_build/default/sihl-email/test/email_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-persistence/test/database_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-storage/test/storage_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-user/test/password_reset_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-user/test/user_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-token/test/mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-web/test/csrf_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-web/test/session_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-web/test/flash_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-web/test/user_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-queue/test/queue_mariadb.exe

test-postgresql: build
	SIHL_ENV=test ./_build/default/sihl-email/test/email_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-persistence/test/database_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-user/test/user_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-web/test/session_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-web/test/flash_postgresql.exe

test-http: build
	SIHL_ENV=test ./_build/default/sihl-web/test/http.exe

test: test-unit test-memory test-http test-postgresql test-mariadb

doc:
	opam exec -- dune build @doc
