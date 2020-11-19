(lang dune 2.7)
(generate_opam_files true)

(name sihl)
(version 0.1.11)

(authors
  "Josef Erben"
  "Aron Erben"
  "Miko Nieminen")

(source (github oxidizing/sihl))
(license MIT)
(maintainers "josef@oxidizing.io")
(homepage "https://github.com/oxidizing/sihl")
(bug_reports "https://github.com/oxidizing/sihl/issues")
(documentation "https://oxidizing.github.io/sihl/")

(package
 (name sihl-core)
 (synopsis "The core of the Sihl web framework")
 (description "Deals with configuration, service lifecycle, app, CLI commands, logging and randomness.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (conformist (>= 0.1.0))
  (tsort (>= 2.0.0))
  (logs (>= 0.7.0))
  (fmt (>= 0.8.8))
  (sexplib (>= v0.13.0))))

(package
 (name sihl)
 (synopsis "A modular functional web framework")
 (description "Build web apps fast with long-term maintainability in mind.")
 (depends
  ;; General system dependencies
  dune
  (ocaml (>= 4.08.0))
  (sihl-core (= :version))

  ;; Web toolkit
  (opium (>= 0.17.1))
  (multipart-form-data (>= 0.3.0))
  (yojson (>= 1.7.0))
  (ppx_deriving_yojson (>= 3.5.2))

  ;; SSL && TLS
  (tls (>= 0.11.1))
  (ssl (>= 0.5.9))
  (lwt_ssl (>= 1.1.3))

  ;; Database interface
  (caqti (>= 1.2.1))
  (caqti-lwt (>= 1.2.0))

  ;; Hashing
  (safepass (>= 3.0))

  ;; JWT
  (jwto (>= 0.3.0))

  ;; UUID
  (uuidm (>= 0.9.7))

  ;; Helpers & Generation
  (ppx_fields_conv (>= v0.13.0))
  (ppx_sexp_conv (>= v0.13.0))

  ;; Test
  (alcotest (>= 1.2.0))

  ;; Test dependencies
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))
  (cohttp-lwt-unix (and (>= 2.5.1) (< 3.0.0) :with-test))))

(package
 (name sihl-storage)
 (synopsis "A Sihl service for storing and retrieving large files")
 (description "
This service can be used to handle large binary blobs that are typically not stored in relational databases. Various storage backends are provided.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl (= :version))))

(package
 (name sihl-email)
 (synopsis "A Sihl service for sending emails using Lwt")
 (description "
A Sihl service for sending emails using Lwt. Various email transports are provided that can be used in production or testing such as SMTP, Sendgrid, in-memory and console printing.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl (= :version))
  (letters (>= 0.2.0))))

(package
 (name sihl-queue)
 (synopsis "A Sihl service for queue jobs")
 (description "
A Sihl service for putting and working jobs on queues. Various queue backends are provided.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl (= :version))))