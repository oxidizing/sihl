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

Create a local switch with `make switch`.

If the compilation of the dependencies failed, you can leave the created switch and run `make deps` to install the dependencies into the created switch later on.

Run `make sihl`, if you see a list of commands Sihl is installed and ready!

Install the asset pipeline by running `npm install`.

## Development

For hot-reloading use `make dev`, this restarts Sihl after you change a file. In a separate process you can run `make assets_watch` to watch the `resource` directory for changes and to compile assets into the `public` directory.

Use `make test` to run the tests.
