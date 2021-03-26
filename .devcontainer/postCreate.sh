# ocaml/opam post create script

# VS code devContainer dependency
sudo chown -R opam: _build

# remove and update default ocaml remote
# make sure that opam finds latest package versions
# (e.g. otherwise alcotest latest version is 1.1.0 instead of 1.2.1)
opam remote remove --all default
opam remote add default https://opam.ocaml.org

# Pins
# opam pin add -yn ocaml-lsp-server https://github.com/ocaml/ocaml-lsp.git

# install opam packages
# e.g. when developing with emax, add also: utop merlin ocamlformat
opam install \
  alcotest-lwt \
  caqti-driver-mariadb \
  caqti-driver-postgresql \
  caqti-lwt \
  cohttp-lwt-unix \
  letters \
  ocaml-lsp-server.1.4.0 \
  opium

# install project dependancies
# pin package
opam pin add . --yes --no-action
# Query and install external dependencies
opam depext sihl sihl-user sihl-storage sihl-email sihl-queue sihl-cache sihl-token --yes --with-doc --with-test
# install dependencies
OPAMSOLVERTIMEOUT=180 opam install . --deps-only --with-doc --with-test --locked --unlock-base
opam install ocamlformat --skip-updates
# upgrade dependencies
opam upgrade --fixup

# initialize project and update environmemnt
opam init
eval $(opam env)
