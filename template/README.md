# Sihl Template App

Clone this template to get a minimal Sihl project.

## Prerequisites

- [opam](https://opam.ocaml.org/doc/Install.html)
- [nodejs](https://nodejs.org/en/download/)

## Using MariaDB

The app is set up to use PostgreSQL. If you want to use MariaDB, make following changes:

1. Change `Sihl.Database.Migration.PostgreSql` to `Sihl.Database.Migration.MariaDb` in `service/service.ml`
2. Change `caqti-driver-postgresql` to `caqti-driver-mariadb` in `run/dune`
3. Change `caqti-driver-postgresql` to `caqti-driver-mariadb` in dune-project

Run `dune build` to update `app.opam`.

## Getting started

Save `.env.sample` and `.env.test.sample` without the `.sample` ending and make your customizations.

Create a local switch with `make switch`. If you get an error message asking whether you want to clean up the created switch, just say no with `n`.

Run `make deps` to install the dependencies into the created switch.

Run `make build` to build the project.

Run `make sihl`, if you see a list of commands Sihl is installed and ready!

## Development

For hot-reloading use `make dev`, this restarts Sihl after you change a file. In a separate process you can run `make assets_watch` to watch the `resource` directory for changes and to compile assets into the `public` directory.

Use `make test` to run the tests.
