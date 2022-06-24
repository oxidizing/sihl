(lang dune 2.8)
(generate_opam_files true)
(name sihl)
(version 4.0.0)
(authors "Josef Erben" "Aron Erben" "Miko Nieminen")
(source (github oxidizing/sihl))
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
  (fileutils (>= 0.6.3))
  (cohttp-lwt-unix (>= 5.0.0))
  (utop (>= 2.9.1))
  (spawn (>= v0.15.1))
  (inotify (>= 2.4))
  (base64 (>= 3.5.0))
  (ppx_enumerate (>= v0.15.0))
  (pgx_lwt_unix (>= 2.0))
  (logs (>= 0.7.0))
  (uri (>= 4.2.0))
  (sexplib0 (>= v0.15.0))
  (yojson (>= 1.7.0))
  (tyxml (>= 4.5.0))
  (ptime (>= 1.0.0))
  (ppx_deriving (>= 5.2.1))
  (lwt (>= 5.5.0))
  (cmdliner (>= 1.1.1))
  (caqti (>= 1.8.0))
  dune
  (ocaml (>= 4.12.0))
  dream
  containers
  containers-data
  omigrate
  minicli
  lwt_ppx
  reason
  ppx_fields_conv
  ppx_deriving_yojson
  caqti-lwt
  fieldslib
  (ppx_inline_test (and :with-test (>= v0.15.0)))
  (ppx_assert (and :with-test (>= v0.15.0)))
  (caqti-driver-postgresql (and (>= 1.8.0) :with-test))
  (caqti-driver-mariadb (and (>= 1.8.0) :with-test))
  (tyxml-jsx (and (>= 4.5.0) :with-test))))
(package
 (name sihl_auth)
 (synopsis "Todo")
 (description "Todo")
 (depends
  (ppx_enumerate (and (>= v0.15.0) :with-test))
  ocaml
  dune
  tyxml
  tyxml-jsx
  sihl
  (ptime (and (>= 1.0.0) :with-test))
  (ppx_inline_test (and (>= v0.15.0) :with-test))
  (ppx_fields_conv (and (>= v0.15.0) :with-test))
  (ppx_deriving_yojson (and (>= 3.6.1) :with-test))
  (ppx_deriving (and (>= 5.2.1) :with-test))
  (ppx_assert (and (>= v0.15.0) :with-test))
  (lwt_ppx (and (>= 2.0.3) :with-test))
  (caqti-driver-postgresql (and (>= 1.8.0) :with-test))
  (caqti-driver-mariadb (and (>= 1.8.0) :with-test))))
