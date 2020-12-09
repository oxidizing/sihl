.PHONY: all test clean

build:
	opam exec -- dune build

clean:
	opam exec -- dune clean

test-unit:
	SIHL_ENV=test opam exec -- dune test

test-mariadb:
	opam exec -- dune build
	SIHL_ENV=test ./_build/default/sihl-web/test/csrf_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-web/test/session_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-web/test/flash_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-email/test/email_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-persistence/test/database_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-user/test/password_reset_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-user/test/token_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-user/test/user_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-user/test/authn_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-queue/test/queue_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-storage/test/storage_mariadb.exe

test-postgresql:
	opam exec -- dune build
	SIHL_ENV=test ./_build/default/sihl-web/test/session_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-web/test/flash_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-persistence/test/database_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-email/test/email_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-email/test/database_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-user/test/user_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-queue/test/queue_postgresql.exe

test-http:
	opam exec -- dune build
	SIHL_ENV=test ./_build/default/sihl-web/test/http.exe

doc:
	opam exec -- dune build @doc
