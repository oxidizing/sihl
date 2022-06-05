(lang dune 2.8)

(generate_opam_files true)

(name sihl)

(version 3.0.3)

(authors "Josef Erben" "Aron Erben" "Miko Nieminen")

(source
 (github oxidizing/sihl))

(license MIT)

(maintainers "Josef Erben")

(homepage "https://github.com/oxidizing/sihl")

(bug_reports "https://github.com/oxidizing/sihl/issues")

(documentation "https://oxidizing.github.io/sihl/")

(package
 (name sihl)
 (synopsis "The Sihl web framework")
 (description
  "\nSihl is a batteries-included web framework. Thanks to the modular architecture, included batteries can be swapped out easily. Statically typed functional programming with OCaml makes web development fun, fast and safe. Sihl supports PostgreSQL and MariaDB.\n")
 (depends
  dune
  (ocaml (>= 4.12.0))
  dream
  containers
  omigrate
  minicli
  lwt_ppx
  reason
  ppx_fields_conv
  ppx_deriving_yojson
  caqti-lwt
  fieldslib
  dune-build-info))

(package
 (name sihl_auth)
 (synopsis "Todo")
 (description
  "Todo")
 (depends
  ocaml
  dune
  tyxml
  tyxml-jsx
  sihl))
