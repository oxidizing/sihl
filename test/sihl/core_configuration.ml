let read_empty_value _ () =
  Sihl.Core.Configuration.store [];
  Alcotest.(
    check
      (option string)
      "empty"
      (Sihl.Core.Configuration.read_string "non-existent")
      None);
  Lwt.return ()
;;

let read_non_existing _ () =
  Sihl.Core.Configuration.store [ "foo", "value" ];
  Alcotest.(
    check
      (option string)
      "empty"
      (Sihl.Core.Configuration.read_string "non-existent")
      None);
  Lwt.return ()
;;

let read_existing _ () =
  Sihl.Core.Configuration.store [ "foo", "value" ];
  Alcotest.(
    check
      (option string)
      "empty"
      (Sihl.Core.Configuration.read_string "foo")
      (Some "value"));
  Lwt.return ()
;;

type config =
  { username : string
  ; port : int option
  ; start_tls : bool
  ; ca_path : string option
  }

let config username port start_tls ca_path = { username; port; start_tls; ca_path }

let sexp_of_config { username; port; start_tls; ca_path } =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  List
    [ List [ Atom "username"; sexp_of_string username ]
    ; List [ Atom "port"; sexp_of_option sexp_of_int port ]
    ; List [ Atom "start_tls"; sexp_of_bool start_tls ]
    ; List [ Atom "ca_path"; sexp_of_option sexp_of_string ca_path ]
    ]
;;

let pp_config fmt t = Sexplib0.Sexp.pp_hum fmt (sexp_of_config t)
let testable_config = Alcotest.of_pp pp_config

let schema =
  let open Conformist in
  make
    [ string "SMTP_USERNAME"
    ; optional (int ~default:587 "SMTP_PORT")
    ; bool "SMTP_START_TLS"
    ; optional (string "SMTP_CA_PATH")
    ]
    config
;;

let read_schema_invalid _ () =
  Sihl.Core.Configuration.store
    [ "SMTP_PORT", "1234"; "SMTP_START_TLS", "true"; "SMTP_CA_PATH", "/ca/file" ];
  Alcotest.check_raises
    "raises"
    (Sihl.Core.Configuration.Exception "CONFIG: Invalid configuration provided")
    (fun () -> Sihl.Core.Configuration.read schema |> ignore);
  Lwt.return ()
;;

let read_schema _ () =
  Sihl.Core.Configuration.store
    [ "SMTP_USERNAME", "username"
    ; "SMTP_PORT", "1234"
    ; "SMTP_START_TLS", "true"
    ; "SMTP_CA_PATH", "/ca/file"
    ];
  Alcotest.(
    check
      testable_config
      "raises"
      (Sihl.Core.Configuration.read schema)
      { username = "username"
      ; port = Some 1234
      ; start_tls = true
      ; ca_path = Some "/ca/file"
      });
  Lwt.return ()
;;