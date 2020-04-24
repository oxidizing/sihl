(lang dune 2.0)
(generate_opam_files true)

(name sihl)
(version 0.1.0)

(authors "Josef Erben")
(license MIT)
(source (uri "git@github.com:oxidizing/sihl.git"))
(maintainers "josef@oxidizing.io")
(homepage "https://github.com/oxidizing/sihl/")
(bug_reports "https://github.com/oxidizing/sihl/issues")
(documentation "") ; TODO

(package
 (name sihl_core)
 (synopsis "A web framework for OCaml.")
 (description "A web framework for OCaml and Reason to build web apps rapidly.")
 (depends
  ;; General system dependencies
  (dune (>= 2))
  (ocaml (>= 4.08.0))

  ;; Standard library replacement
  (core (>= v0.12.2))

  ;; Web toolkit
  (opium (>= 0.17.1))
  (yojson (>= 1.7.0))
  (ppx_deriving_yojson (>= 3.5.2))

  ;; Database interface
  (caqti (>= 1.2.1))
  (caqti-lwt (>= 1.2.0))
  (caqti-driver-postgresql (>= 1.2.1))
  (ppx_rapper (>= 0.9.2))

  ;; HTML generation
  (tyxml (>= 4.3.0))

  ;; Logging
  (logs (>= 0.7.0))
  (fmt (>= 0.8.8))

  ;; Helpers
  (pcre (>= 7.4.3))
  (sexplib (>= 0.13.0))
  (ppx_fields_conv (>= 0.13.0))
  (ppx_sexp_conv (>= 0.13.0))
  (ppx_string_interpolation (>= 1.0.0))
  (ctypes (>= 0.17.1))

  ;; Dev dependencies
  (utop :dev)
  (merlin :dev)
  (ocamlformat :dev)
  (ocp-indent :dev)
  (tuareg :dev) ;; rm if not using emacs
))

(package
 (name sihl_users)
 (synopsis "A web framework for OCaml.")
 (description "A web framework for OCaml and Reason to build web apps rapidly.")
 (depends
  ;; General system dependencies
  (dune (>= 2))
  (ocaml (>= 4.08.0))

  ;; Standard library replacement
  (core (>= v0.12.2))

  ;; Web toolkit
  (opium (>= 0.17.1))
  (yojson (>= 1.7.0))
  (ppx_deriving_yojson (>= 3.5.2))
  (uuidm (>= 0.9.7))

  ;; Database interface
  (caqti (>= 1.2.1))
  (caqti-lwt (>= 1.2.0))
  (caqti-driver-postgresql (>= 1.2.1))
  (ppx_rapper (>= 0.9.2))

  ;; HTML generation
  (tyxml (>= 4.3.0))

  ;; Logging
  (logs (>= 0.7.0))
  (fmt (>= 0.8.8))

  ;; Hashing
  (safepass (>= 3.0))

  ;; Helpers
  (pcre (>= 7.4.3))
  (ppx_fields_conv (>= 0.13.0))
  (ppx_sexp_conv (>= 0.13.0))
  (ppx_string_interpolation (>= 1.0.0))

  ;; Dev dependencies
  (utop :dev)
  (merlin :dev)
  (ocamlformat :dev)
  (ocp-indent :dev)
  (tuareg :dev) ;; rm if not using emacs
))
