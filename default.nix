with import <nixpkgs> { };

mkShell {
  buildInputs = [ zlib.dev zlib.out zlib zlib.all gmp gmp.dev pkgconfig openssl libev libevdev mariadb-client mariadb-connector-c postgresql ];
  LD_LIBRARY_PATH = "${mariadb-connector-c}/lib/mariadb";
  shellHook = "eval $(opam env)";
}
