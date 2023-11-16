with import <nixpkgs> { };

mkShell {
  buildInputs = [ yarn zlib.dev zlib.out zlib zlib.all gmp gmp.dev pkg-config openssl libev libevdev mariadb-client mariadb-connector-c postgresql ];
  LD_LIBRARY_PATH = "${mariadb-connector-c}/lib/mariadb";
  shellHook = "eval $(opam env)";
}
