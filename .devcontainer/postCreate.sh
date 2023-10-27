#!/bin/sh

# immediately when a command fails and print each command
set -ex

sudo chown -R opam: _build
sudo chown -R opam: node_modules

opam init -a --shell=zsh

# get newest opam packages
opam remote remove --all default
opam remote add default https://opam.ocaml.org

opam pin add . --yes --no-action
opam depext sihl sihl-user sihl-storage sihl-email sihl-queue sihl-cache sihl-token --yes --with-doc --with-test

eval $(opam env)

# install opam packages used for vscode ocaml platform package
# e.g. when developing with emax, add also: utop merlin ocamlformat
make deps

# install yarn packages
yarn
