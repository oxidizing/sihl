.DEFAULT_GOAL := all

ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
ARGS := $(subst :,\:,$(ARGS))
$(eval $(ARGS):;@:)

.PHONY: all
all:
	opam exec -- dune build --root . @install

.PHONY: deps
deps:
	opam install -y dune-release merlin ocamlformat utop
	opam install -y alcotest-lwt mariadb.1.1.6 caqti-driver-postgresql.2.0.1 caqti-driver-mariadb.2.0.1
	opam install . -y --deps-only --locked
	eval $(opam env)

.PHONY: create_switch
create_switch:
	opam switch create . 4.14.1 --no-install --locked
	eval $(opam env)

.PHONY: switch
switch: create_switch deps ## Create an opam switch and install development dependencies

.PHONY: lock
lock: ## Generate a lock file
	opam lock -y .

.PHONY: watch
watch: ## Build the project, including non installable libraries and executables
	opam exec -- dune build -w --root .

.PHONY: build
build: ## Build the project, including non installable libraries and executables
	opam exec -- dune build --root .

.PHONY: install
install: all ## Install the packages on the system
	opam exec -- dune install --root .

.PHONY: clean
clean: ## Clean build artifacts and other generated files
	opam exec -- dune clean --root .

.PHONY: format
format: build ## Format the codebase with ocamlformat
	opam exec -- dune build --root . --auto-promote @fmt

.PHONY: sihl
sihl: all ## Run the produced executable of the included Sihl app
	ROOT_PATH=$(CURDIR)/example opam exec -- dune exec --root . example/run/run.exe $(ARGS)

.PHONY: test
test: build	## Run unit tests with dune and then all sihl tests
	SIHL_ENV=test ./_build/default/sihl/test/core_app.exe
	SIHL_ENV=test ./_build/default/sihl/test/core_configuration.exe
	SIHL_ENV=test ./_build/default/sihl/test/core_container.exe
	SIHL_ENV=test ./_build/default/sihl/test/core_utils.exe
	SIHL_ENV=test ./_build/default/sihl/test/web.exe
	SIHL_ENV=test ./_build/default/sihl/test/web_flash.exe
	SIHL_ENV=test ./_build/default/sihl/test/web_id.exe
	SIHL_ENV=test ./_build/default/sihl/test/web_trailing_slash.exe
	SIHL_ENV=test ./_build/default/sihl/test/web_session.exe
	SIHL_ENV=test ./_build/default/sihl/test/web_csrf.exe
	SIHL_ENV=test ./_build/default/sihl/test/web_http.exe
	SIHL_ENV=test ./_build/default/sihl/test/database_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl/test/database_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl/test/database_migration_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl/test/database_migration_postgresql.exe

.PHONY: test-cache
test-cache: build
	SIHL_ENV=test ./_build/default/sihl-cache/test/mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-cache/test/postgresql.exe

.PHONY: test-email
test-email: build
	SIHL_ENV=test ./_build/default/sihl-email/test/template.exe
	SIHL_ENV=test ./_build/default/sihl-email/test/email_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-email/test/email_postgresql.exe

.PHONE: test-queue
test-queue: build
	SIHL_ENV=test ./_build/default/sihl-queue/test/queue_inmemory.exe
	SIHL_ENV=test ./_build/default/sihl-queue/test/queue_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-queue/test/queue_postgresql.exe

.PHONE: test-storage
test-storage: build
	SIHL_ENV=test ./_build/default/sihl-storage/test/storage_mariadb.exe

.PHONE: test-token
test-token: build
	SIHL_ENV=test ./_build/default/sihl-token/test/jwt_inmemory.exe
	SIHL_ENV=test ./_build/default/sihl-token/test/mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-token/test/jwt_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-token/test/postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-token/test/jwt_postgresql.exe

.PHONE: test-user
test-user: build
	SIHL_ENV=test ./_build/default/sihl-user/test/user_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-user/test/user_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-user/test/password_reset_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-user/test/password_reset_postgresql.exe

.PHONY: test-all
test-all: test test-cache test-email test-queue test-storage test-token test-user

.PHONY: utop
utop: ## Run a REPL and link with the project's libraries
	opam exec -- dune utop --root . lib -- -implicit-bindings

.PHONY: fmt
fmt:
	opam exec -- dune build --root . --auto-promote @fmt

.PHONY: db
db: ## Starts the database using docker-compose
	docker-compose -f docker-compose.dev.yml up -d

.PHONY: db_down
db_down: ## Removes the database using docker-compose
	docker-compose -f docker-compose.dev.yml down
