(lang dune 2.0)
(generate_opam_files true)

(name sihl)
(version 0.0.32)

(authors "Josef Erben")
(license MIT)
(maintainers "josef@oxidizing.io")
(homepage "https://github.com/oxidizing/sihl")
(bug_reports "https://github.com/oxidizing/sihl/issues")
(documentation "https://github.com/oxidizing/sihl")

(package
 (name sihl)
 (synopsis "A web framework for Reason and OCaml")
 (description "A web framework for Reason and OCaml to build apps rapidly.")
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
  (tyxml-jsx (>= 4.3.0))
  (reason (>= 3.0.0))

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
 (name sihl_postgresql)
 (synopsis "Provides support for migrations using PostgreSQL")
 (description "Provides support for migrations using PostgreSQL.")
 (license MIT)
 (depends
  (sihl (>= 0.0.32))
  (caqti-driver-postgresql (>= 1.2.1))
  (ppx_rapper (>= 0.9.2))
))

(package
 (name sihl_mariadb)
 (synopsis "Provides support for migrations using MariaDB")
 (description "Provides support for migrations using MariaDB.")
 (license MIT)
 (depends
  (sihl (>= 0.0.32))
  (caqti-driver-mariadb (>= 1.2.1))
))

(package
 (name sihl_admin)
 (synopsis "A Sihl app to build backoffice web applications for administrators")
 (description "This app provides a building blocks to build and register admin pages to increase visibility and provide administrators with internal tools..")
 (license MIT)
 (depends
  ;; General system dependencies
  (dune (>= 2))
  (ocaml (>= 4.08.0))
  (lwt (>= 5.3.0))

  ;; Sihl
  (sihl (>= 0.0.32))

  ;; Standard library replacement
  (base (>= v0.13.1))
))


(package
 (name sihl_session)
 (synopsis "A Sihl app for anonymous sessions")
 (description "This app provides a generic interface to store and retrieve anonymous session data. It is mainly used to build other apps on top.")
 (license MIT)
 (depends
  ;; General system dependencies
  (dune (>= 2))
  (ocaml (>= 4.08.0))
  (lwt (>= 5.3.0))

  ;; Sihl
  (sihl (>= 0.0.32))

  ;; Standard library replacement
  (base (>= v0.13.1))
))

(package
 (name sihl_session_mariadb)
 (synopsis "An implementation of the session store using MariaDB")
 (description "An implementation of the session store using MariaDB.")
 (license MIT)
 (depends
  (sihl_session (>= 0.0.32))
  (caqti-driver-mariadb (>= 1.2.1))
  ))

(package
 (name sihl_session_postgresql)
 (synopsis "An implementation of the session store using PostgreSQL")
 (description "An implementation of the session store using PostgreSQL.")
 (license MIT)
 (depends
  (sihl_session (>= 0.0.32))
  (caqti-driver-postgresql (>= 1.2.1))
  (ppx_rapper (>= 0.9.2))
))

(package
 (name sihl_email)
 (synopsis "A Sihl app for email management")
 (description "Use this app to send single emails and schedule sending over various email backends.")
 (license MIT)
 (depends
  ;; General system dependencies
  (dune (>= 2))
  (ocaml (>= 4.08.0))
  (lwt (>= 5.3.0))

  ;; Sihl
  (sihl (>= 0.0.32))

  ;; Standard library replacement
  (base (>= v0.13.1))
))

(package
 (name sihl_email_mariadb)
 (synopsis "A storage for emails, templates and email queues using MariaDB")
 (description "A storage for emails, templates and email queues using MariaDB.")
 (license MIT)
 (depends
  (sihl_email (>= 0.0.32))
  (caqti-driver-mariadb (>= 1.2.1))
))

(package
 (name sihl_email_postgresql)
 (synopsis "A storage for emails, templates and email queues using PostgreSQL")
 (description "A storage for emails, templates and email queues using PostgreSQL.")
 (license MIT)
 (depends
  (sihl_email (>= 0.0.32))
  (caqti-driver-postgresql (>= 1.2.1))
  (ppx_rapper (>= 0.9.2))
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
  (sihl (>= 0.0.32))
  (sihl_email (>= 0.0.32))

  ;; Standard library replacement
  (base (>= v0.13.1))

  ;; Database
  (ppx_rapper (>= 0.9.2))
))

(package
 (name sihl_user_mariadb)
 (synopsis "A storage for users using MariaDB")
 (description "A storage for users using MariaDB.")
 (license MIT)
 (depends
  (sihl_user (>= 0.0.32))
  (caqti-driver-mariadb (>= 1.2.1))
))

(package
 (name sihl_user_postgresql)
 (synopsis "A storage for users using PostgreSQL")
 (description "A storage for users using PostgreSQL.")
 (license MIT)
 (depends
  (sihl_user (>= 0.0.32))
  (caqti-driver-postgresql (>= 1.2.1))
  (ppx_rapper (>= 0.9.2))
))
