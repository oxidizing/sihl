#!/bin/sh

# immediately when a command fails and print each command
set -ex

sudo chown -R opam: _build
sudo chown -R opam: node_modules

opam init -a --shell=zsh

# get newest opam packages
opam remote remove --all default
opam remote add default https://opam.ocaml.org

# TODO: remove pins when the packages are released
opam pin add -yn opium https://github.com/mabiede/opium.git#upgrade-packages
opam pin add -yn rock https://github.com/mabiede/opium.git#upgrade-packages

# install dev dependencies
opam install --yes --with-doc --with-test --deps-only --working-dir .

eval $(opam env)

# install opam packages used for vscode ocaml platform package
# e.g. when developing with emax, add also: utop merlin ocamlformat
make deps

# install yarn packages
yarn
