(lang dune 2.7)

(generate_opam_files true)

(name sihl)

(version 4.0.0)

(authors "Josef Erben" "Aron Erben" "Miko Nieminen")

(source
 (github oxidizing/sihl))

(license MIT)

(maintainers "josef@oxidizing.io")

(homepage "https://github.com/oxidizing/sihl")

(bug_reports "https://github.com/oxidizing/sihl/issues")

(documentation "https://oxidizing.github.io/sihl/")

(package
 (name sihl)
 (synopsis "The Sihl web framework")
 (description
  "\nSihl is a batteries-included web framework. Thanks to the modular architecture, included batteries can be swapped out easily. Statically typed functional programming with OCaml makes web development fun, fast and safe. Sihl supports PostgreSQL and MariaDB.\n")
 (depends
  dune
  (ocaml
   (>= 4.12.0))
  (conformist
   (>= 0.8.1))
  (dune-build-info
   (>= 2.8.4))
  (tsort
   (>= 2.0.0))
  (containers
   (>= 3.6.1))
  (logs
   (>= 0.7.0))
  (fmt
   (>= 0.8.8))
  (bos
   (>= 0.2.0))
  (sexplib
   (>= v0.13.0))
  (yojson
   (>= 1.7.0))
  (ppx_deriving_yojson
   (>= 3.5.2))
  (tls
   (>= 1.0.4))
  (ssl
   (>= 0.5.9))
  (lwt_ssl
   (>= 1.1.3))
  (lwt_ppx
   (>= 2.0.1))
  (caqti
   (>= 2.0.1))
  (caqti-lwt
   (>= 2.0.1))
  (safepass
   (>= 3.0))
  (jwto
   (>= 0.3.0))
  (uuidm
   (>= 0.9.9))
  (ppx_fields_conv
   (>= v0.13.0))
  (ppx_sexp_conv
   (>= v0.13.0))
  (mirage-crypto
   (>= 1.1.0))
  (mirage-crypto-rng
   (>= 1.2.0))
  (cstruct
   (>= 6.0.1))
  (opium
   (>= 0.20.0))
  (cohttp-lwt-unix
   (and
    (>= 2.5.4)
    :with-test))
  (alcotest-lwt
   (and
    (>= 1.4.0)
    :with-test))
  (mariadb
   (>= 1.1.6))
  (caqti-driver-postgresql
   (and
    (>= 2.0.1)
    :with-test))
  (caqti-driver-mariadb
   (and
    (>= 2.0.1)
    :with-test))))

(package
 (name sihl-user)
 (synopsis "User service implementations for Sihl")
 (description
  "Modules for user management and password reset workflows with support for PostgreSQL and MariaDB.")
 (depends
  dune
  (ocaml
   (>= 4.08.0))
  (sihl
   (= :version))
  (sihl-token
   (and
    (= :version)
    :with-test))
  (alcotest-lwt
   (and
    (>= 1.4.0)
    :with-test))
  (mariadb
   (>= 1.1.6))
  (caqti-driver-postgresql
   (and
    (>= 2.0.1)
    :with-test))
  (caqti-driver-mariadb
   (and
    (>= 2.0.1)
    :with-test))))

(package
 (name sihl-cache)
 (synopsis "Cache service implementations for Sihl")
 (description "A key-value store with support for PostgreSQL and MariaDB.")
 (depends
  dune
  (ocaml
   (>= 4.08.0))
  (sihl
   (= :version))
  (alcotest-lwt
   (and
    (>= 1.4.0)
    :with-test))
  (mariadb
   (>= 1.1.6))
  (caqti-driver-postgresql
   (and
    (>= 2.0.1)
    :with-test))
  (caqti-driver-mariadb
   (and
    (>= 2.0.1)
    :with-test))))

(package
 (name sihl-token)
 (synopsis "Token service implementations for Sihl")
 (description
  "Modules for token handling with support for JWT blacklisting and server-side stored tokens using PostgreSQL and MariaDB.")
 (depends
  dune
  (ocaml
   (>= 4.08.0))
  (sihl
   (= :version))
  (alcotest-lwt
   (and
    (>= 1.4.0)
    :with-test))
  (mariadb
   (>= 1.1.6))
  (caqti-driver-postgresql
   (and
    (>= 2.0.1)
    :with-test))
  (caqti-driver-mariadb
   (and
    (>= 2.0.1)
    :with-test))))

(package
 (name sihl-storage)
 (synopsis "Storage service implementations for Sihl")
 (description
  "Modules for storing large binary blobs using either PostgreSQL or MariaDB.")
 (depends
  dune
  (ocaml
   (>= 4.08.0))
  (sihl
   (= :version))
  (alcotest-lwt
   (and
    (>= 1.4.0)
    :with-test))
  (mariadb
   (>= 1.1.6))
  (caqti-driver-postgresql
   (and
    (>= 2.0.1)
    :with-test))
  (caqti-driver-mariadb
   (and
    (>= 2.0.1)
    :with-test))))

(package
 (name sihl-email)
 (synopsis "Email service implementations for Sihl")
 (description "Modules for sending emails using Lwt and SMTP or Sendgrid.")
 (depends
  dune
  (ocaml
   (>= 4.08.0))
  (letters
   (>= 0.4.0))
  (sihl
   (= :version))
  (cohttp-lwt-unix
   (>= 2.5.4))
  (alcotest-lwt
   (and
    (>= 1.4.0)
    :with-test))
  (mariadb
   (>= 1.1.6))
  (caqti-driver-postgresql
   (and
    (>= 2.0.1)
    :with-test))
  (caqti-driver-mariadb
   (and
    (>= 2.0.1)
    :with-test))))

(package
 (name sihl-queue)
 (synopsis "Queue service implementations for Sihl")
 (description
  "Modules for running tasks in the background on a persistent queue.")
 (depends
  dune
  (ocaml
   (>= 4.08.0))
  (sihl
   (= :version))
  (tyxml-ppx
   (>= 4.4.0))
  (alcotest-lwt
   (and
    (>= 1.4.0)
    :with-test))
  (mariadb
   (>= 1.1.6))
  (caqti-driver-postgresql
   (and
    (>= 2.0.1)
    :with-test))
  (caqti-driver-mariadb
   (and
    (>= 2.0.1)
    :with-test))))
