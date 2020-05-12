(lang dune 2.0)
(generate_opam_files true)

(name sihl_core)
(version 0.0.26)

(authors "Josef Erben")
(license MIT)
(maintainers "josef@oxidizing.io")
(homepage "https://github.com/oxidizing/sihl")
(bug_reports "https://github.com/oxidizing/sihl/issues")
(documentation "https://github.com/oxidizing/sihl")

(package
 (name sihl_core)
 (synopsis "A web framework for Reason and OCaml")
 (description "A web framework for Reason and OCaml to build web apps rapidly.")
 (license MIT)
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

  ;; SSL && TLS
  (tls (>= 0.11.1))
  (ssl (>= 0.5.9))
  (lwt_ssl (>= 1.1.3))

  ;; Database interface
  (caqti (>= 1.2.1))
  (caqti-lwt (>= 1.2.0))

  ;; Database
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

  ;; UUID
  (uuidm (>= 0.9.7))

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
 (name sihl_email)
 (synopsis "An email management app for Sihl")
 (description "Use this app to send single emails and schedule sending over various email backends.")
 (license MIT)
 (depends
  ;; General system dependencies
  (dune (>= 2))
  (ocaml (>= 4.08.0))
  (lwt (>= 5.3.0))

  ;; Sihl
  (sihl_core (>= 0.0.26))

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

(package
 (name sihl_user)
 (synopsis "A user management app for Sihl")
 (description "This app provides an Admin UI, Email confirmation & Password reset workflows, an HTTP API and a Service API supporting MariaDB and Postgres.")
 (license MIT)
 (depends
  ;; General system dependencies
  (dune (>= 2))
  (ocaml (>= 4.08.0))
  (lwt (>= 5.3.0))

  ;; Sihl
  (sihl_core (>= 0.0.26))
  (sihl_email (>= 0.0.26))

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
