# ocaml/opam post create script

sudo chown -R opam: _build
sudo chown -R opam: node_modules

# initialize project and update environmemnt
opam init -a --shell=zsh
eval $(opam env)

# get newest opam packages
opam remote remove --all default
opam remote add default https://opam.ocaml.org

# ensure all system dependencies are installed
opam pin add . --yes --no-action
opam depext sihl sihl-user sihl-storage sihl-email sihl-queue sihl-cache sihl-token --yes --with-doc --with-test

# install opam packages used for vscode ocaml platform package
# e.g. when developing with emax, add also: utop merlin ocamlformat
make deps
opam install -y ocaml-lsp-server
