(lang dune 2.4)
(generate_opam_files true)

(name sihl)
(version 0.1.0)

(authors "Josef Erben")
(source (github oxidizing/sihl))
(license MIT)
(maintainers "josef@oxidizing.io")
(homepage "https://github.com/oxidizing/sihl")
(bug_reports "https://github.com/oxidizing/sihl/issues")
(documentation "https://oxidizing.github.io/sihl/")

(package
 (name sihl)
 (synopsis "The modular functional web framework")
 (description "Build web apps fast with long-term maintainability in mind.")
 (depends
  ;; General system dependencies
  (dune (>= 2.4))
  (ocaml (>= 4.08.0))
  (lwt (>= 5.3.0))

  ;; Standard library replacement
  (base (>= v0.13.1))

  ;; Web toolkit
  (opium (>= 0.17.1))
  (yojson (>= 1.7.0))
  (ppx_deriving_yojson (>= 3.5.2))

  ;; Algorithms
  (tsort (>= 2.0.0))

  ;; SSL && TLS
  (tls (>= 0.11.1))
  (ssl (>= 0.5.9))
  (lwt_ssl (>= 1.1.3))

  ;; Database interface
  (caqti (>= 1.2.1))
  (caqti-lwt (>= 1.2.0))

  ;; HTML generation
  (tyxml (>= 4.3.0))
  (tyxml-jsx (>= 4.3.0))
  (reason (>= 3.0.0))

  ;; Logging
  (logs (>= 0.7.0))
  (fmt (>= 0.8.8))

  ;; Regex
  (pcre (>= 7.4.3))

  ;; Hashing
  (safepass (>= 3.0))

  ;; JWT
  (jwto (>= 0.3.0))

  ;; UUID
  (uuidm (>= 0.9.7))

  ;; SMTP
  (letters (>= 0.2.0))

  ;; Helpers & Generation
  (sexplib (>= 0.13.0))
  (ppx_fields_conv (>= 0.13.0))
  (ppx_sexp_conv (>= 0.13.0))

  ;; Test
  (alcotest (>= 1.2.0))

  ;; Dev dependencies
  (utop :dev)
  (merlin :dev)
  (ocamlformat :dev)
  (ocp-indent :dev)
  (tuareg :dev)

  ;; Test dependencies
  (alcotest (and (>= 1.2.0) :with-test))
  (alcotest-lwt (and (>= 1.2.0) :with-test))
  (cohttp-lwt-unix (and (>= 2.5.1) :with-test))
))
