(lang dune 2.7)
(generate_opam_files true)

(name sihl)
(version 0.4.0)

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
 (description "Modules for dealing with configuration, service lifecycle, app, CLI commands, logging, random number generation and schedules.")
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
  (uuidm (>= 0.9.7))
  (lwt_ssl (>= 1.1.3))
  (caqti (>= 1.2.1))
  (safepass (>= 3.0))
  (jwto (>= 0.3.0))
  (uuidm (>= 0.9.7))
  (ppx_fields_conv (>= v0.13.0))
  (ppx_sexp_conv (>= v0.13.0))

  (cohttp-lwt-unix (and (>= 2.5.4) :with-test))
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))))

(package
 (name sihl-contract)
 (synopsis "Sihl serivce interfaces")
 (description "Module signatures and types that can be implemented to create services that can be registered in a Sihl app. The interfaces define a standard for the Sihl ecosystem.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-core (= :version))
  (opium (>= 0.20.0))
  (caqti-lwt (>= 1.2.0))))

(package
 (name sihl-facade)
 (synopsis "Sihl service facade that uses the facade pattern to hide service implementations")
 (description "The facade provides API to register service implementations as the main mechanism for dependency injection.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-contract (= :version))
  (sihl-core (= :version))
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))))

(package
 (name sihl-persistence)
 (synopsis "Sihl services to deal with data persistence")
 (description "Modules for database pools, transactions, migrations and integration tests involving the database layer.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-facade (= :version))
  (caqti (>= 1.2.1))
  (caqti-lwt (>= 1.2.0))
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))))

(package
 (name sihl-web)
 (synopsis "Sihl HTTP service and middlewares")
 (description "An Opium based HTTP service and a set of middlewares to implement traditional web forms and JSON APIs.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-facade (= :version))
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))))

(package
 (name sihl-user)
 (synopsis "Sihl services to deal with users")
 (description "Modules for user handling and password reset workflows.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-facade (= :version))
  (sihl-persistence (= :version))
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))))

(package
 (name sihl-session)
 (synopsis "Sihl service to deal with sessions")
 (description "Modules for session storage.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-facade (= :version))
  (sihl-persistence (= :version))
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))))

(package
 (name sihl-token)
 (synopsis "Sihl service to deal with tokens")
 (description "Modules for token handling with support for JWT blacklisting and database-based tokens.")
 (depends
  dune
  (ocaml (>= 4.08.0))
  (sihl-facade (= :version))
  (sihl-persistence (= :version))
  (alcotest-lwt (and (>= 1.2.0) (< 3.0.0) :with-test))))

(package
 (name sihl-storage)
 (synopsis "Sihl service to deal with storage of large files")
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
 (synopsis "Sihl service to deal with sending emails")
 (description "
Modules for sending emails using Lwt. Various email transports are provided that can be used in production or testing such as SMTP, Sendgrid, in-memory and console printing.")
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
 (synopsis "Sihl service to deal with queuing jobs")
 (description "
Modules for putting and working jobs on queues. Various queue backends are provided.")
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
  (sihl-token (= :version))
  (sihl-session (= :version))
  (sihl-user (= :version))
  (sihl-queue (= :version))
  (sihl-storage (= :version))
  (sihl-email (= :version))))