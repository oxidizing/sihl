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
(documentation "A web framework for Reason and OCaml.")

(package
 (name sihl_core)
 (synopsis "A web framework for Reason and OCaml.")
 (description "A web framework for Reason and OCaml to build web apps rapidly.")
 (depends
  ;; General system dependencies
  (dune (>= 2))
  (ocaml (>= 4.08.0))
  (lwt (>= 5.3.0))

  ;; Standard library replacement
  (base (>= v0.13.1))

  ;; Web toolkit
  (opium (>= 0.17.1))
  (yojson (>= 1.7.0))
  (ppx_deriving_yojson (>= 3.5.2))

  ;; Database interface
  (caqti (>= 1.2.1))
  (caqti-lwt (>= 1.2.0))
  (caqti-driver-postgresql (>= 1.2.1))
  (caqti-driver-mariadb (>= 1.2.1))
  (ppx_rapper (>= 0.9.2))

  ;; HTML generation
  (tyxml (>= 4.3.0))
  (tyxml-ppx (>= 4.3.0))

  ;; Logging
  (logs (>= 0.7.0))
  (fmt (>= 0.8.8))

  ;; Regex
  (pcre (>= 7.4.3))

  ;; Hashing
  (safepass (>= 3.0))

  ;; Helpers & Generation
  (sexplib (>= 0.13.0))
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

(package
 (name sihl_users)
 (synopsis "A user management app for Sihl.")
 (description "This app provides an Admin UI, Email confirmation & Password reset workflows, an HTTP API and a Service API supporting MariaDB and Postgres.")
 (depends
  ;; General system dependencies
  (dune (>= 2))
  (ocaml (>= 4.08.0))
  (lwt (>= 5.3.0))

  ;; Standard library replacement
  (base (>= v0.13.1))

  ;; Database
  (ppx_rapper (>= 0.9.2))

  ;; Dev dependencies
  (utop :dev)
  (merlin :dev)
  (ocamlformat :dev)
  (ocp-indent :dev)
  (tuareg :dev) ;; rm if not using emacs
))
