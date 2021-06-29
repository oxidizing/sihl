# ocaml/opam post create script

sudo chown -R opam: _build
sudo chown -R opam: node_modules

# initialize project and update environmemnt
opam init -a --shell=zsh
eval $(opam env)

# ensure all system dependencies are installed
opam pin add . --yes --no-action
opam depext -y app --with-doc

# install opam packages used for vscode ocaml platform package
# e.g. when developing with emax, add also: utop merlin ocamlformat
make deps
