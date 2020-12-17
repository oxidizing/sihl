(lang dune 2.7)
(generate_opam_files true)

(name sihl)
(version 0.2.1)

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
  (sexplib (>= v0.13.0))
  (yojson (>= 1.7.0))
  (ppx_deriving_yojson (>= 3.5.2))
  (tls (>= 0.11.1))
  (ssl (>= 0.5.9))
  (lwt_ssl (>= 1.1.3))
  (caqti (>= 1.2.1))
  (safepass (>= 3.0))
  (jwto (>= 0.3.0))
  (ppx_fields_conv (>= v0.13.0))
  (ppx_sexp_conv (>= v0.13.0))

  (cohttp-lwt-unix (and (>= 2.5.4) :with-test))
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))))

(package
 (name sihl-contract)
 (synopsis "Contains Sihl service signatures")
 (description "Use the service contracts to implement your own services with the rest of the Sihl ecosystem.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-core (= :version))
  (opium (>= 0.20.0))
  (caqti-lwt (>= 1.2.0))
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))))

(package
 (name sihl-facade)
 (synopsis "Contains the service facade layer of Sihl")
 (description "The facade comprises of the API of all Sihl services. Implementations can be swapped transparently.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-contract (= :version))
  (sihl-core (= :version))))

(package
 (name sihl-persistence)
 (synopsis "Contains Sihl services regarding data persistence")
 (description "Use this package to deal with database pools, transactions, migrations and integration tests involving the database layer.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-facade (= :version))
  (caqti (>= 1.2.1))
  (caqti-lwt (>= 1.2.0))
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))))

(package
 (name sihl-web)
 (synopsis "Contains HTTP server implementations as Sihl service")
 (description "Use this package to implement run your HTTP routers on a HTTP server.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-contract (= :version))
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))))

(package
 (name sihl-user)
 (synopsis "Contains Sihl services to deal with user related topics")
 (description "Use this package to handle tokens, sessions, users, flash messages and password reset workflows.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-facade (= :version))
  (sihl-persistence (= :version))
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))))

(package
 (name sihl-storage)
 (synopsis "A Sihl service for storing and retrieving large files")
 (description "
This service can be used to handle large binary blobs that are typically not stored in relational databases. Various storage backends are provided.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-facade (= :version))
  (sihl-persistence (= :version))
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))))

(package
 (name sihl-email)
 (synopsis "A Sihl service for sending emails using Lwt")
 (description "
A Sihl service for sending emails using Lwt. Various email transports are provided that can be used in production or testing such as SMTP, Sendgrid, in-memory and console printing.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (letters (>= 0.2.1))
  (sihl-facade (= :version))
  (sihl-persistence (= :version))
  (cohttp-lwt-unix (>= 2.5.4))
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))))

(package
 (name sihl-queue)
 (synopsis "A Sihl service for queue jobs")
 (description "
A Sihl service for putting and working jobs on queues. Various queue backends are provided.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-facade (= :version))
  (sihl-persistence (= :version))
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))))

(package
 (name sihl)
 (synopsis "A modular functional web framework")
 (description "Build web apps fast with long-term maintainability in mind.")
 (depends
  ;; General system dependencies
  dune
  (ocaml (>= 4.08.0))
  (sihl-core (= :version))
  (sihl-contract (= :version))
  (sihl-facade (= :version))
  (sihl-persistence (= :version))
  (sihl-web (= :version))
  (sihl-user (= :version))
  (sihl-queue (= :version))
  (sihl-storage (= :version))
  (sihl-email (= :version))))