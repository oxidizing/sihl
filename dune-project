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
 (name sihl-type)
 (synopsis "Contains Sihl types that are returned by Sihl services")
 (description "Use this package together with sihl-contract to implement your own services. Sihl types are things like Email.t, User.t, Queue_job.t or Migration.t.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-core (= :version))
  (opium (>= 0.20.0))
  (caqti-lwt (>= 1.2.0))
  (multipart-form-data (>= 0.3.0))
  (uuidm (>= 0.9.7))
  (alcotest (>= 1.2.0))
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))))

(package
 (name sihl-contract)
 (synopsis "Contains Sihl service signatures")
 (description "Use the service contracts to implement your own services with the rest of the Sihl ecosystem.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-type (= :version))
  (sihl-core (= :version))))

(package
 (name sihl-persistence)
 (synopsis "Contains Sihl services regarding data persistence")
 (description "Use this package to deal with database pools, transactions, migrations and integration tests involving the database layer.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-contract (= :version))
  (caqti (>= 1.2.1))
  (caqti-lwt (>= 1.2.0))))

(package
 (name sihl-web)
 (synopsis "Contains HTTP server implementations as Sihl service")
 (description "Use this package to implement run your HTTP routers on a HTTP server.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-contract (= :version))
  (opium (>= 0.20.0))
  (multipart-form-data (>= 0.3.0))))

(package
 (name sihl-user)
 (synopsis "Contains Sihl services to deal with user related topics")
 (description "Use this package to handle tokens, sessions, users, flash messages and password reset workflows.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-contract (= :version))
  (sihl-persistence (= :version))))

(package
 (name sihl-storage)
 (synopsis "A Sihl service for storing and retrieving large files")
 (description "
This service can be used to handle large binary blobs that are typically not stored in relational databases. Various storage backends are provided.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-contract (= :version))
  (sihl-persistence (= :version))))

(package
 (name sihl-email)
 (synopsis "A Sihl service for sending emails using Lwt")
 (description "
A Sihl service for sending emails using Lwt. Various email transports are provided that can be used in production or testing such as SMTP, Sendgrid, in-memory and console printing.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (letters (>= 0.2.1))
  (sihl-contract (= :version))
  (sihl-persistence (= :version))
  (cohttp-lwt-unix (>= 2.5.4))))

(package
 (name sihl-queue)
 (synopsis "A Sihl service for queue jobs")
 (description "
A Sihl service for putting and working jobs on queues. Various queue backends are provided.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-contract (= :version))
  (sihl-persistence (= :version))))

(package
 (name sihl)
 (synopsis "A modular functional web framework")
 (description "Build web apps fast with long-term maintainability in mind.")
 (depends
  ;; General system dependencies
  dune
  (ocaml (>= 4.08.0))
  (sihl-core (= :version))
  (sihl-type (= :version))
  (sihl-contract (= :version))
  (sihl-persistence (= :version))
  (sihl-web (= :version))
  (sihl-user (= :version))
  (sihl-queue (= :version))
  (sihl-storage (= :version))
  (sihl-email (= :version))
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))
  (cohttp-lwt-unix (and (>= 2.5.1) (< 3.0.0) :with-test))))