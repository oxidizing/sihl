let read_empty_value _ () =
  Sihl.Configuration.store [];
  Alcotest.(
    check
      (option string)
      "empty"
      (Sihl.Configuration.read_string "non-existent")
      None);
  Lwt.return ()
;;

let read_non_existing _ () =
  Sihl.Configuration.store [ "foo", "value" ];
  Alcotest.(
    check
      (option string)
      "different"
      (Sihl.Configuration.read_string "non-existent")
      None);
  Lwt.return ()
;;

let read_existing _ () =
  Sihl.Configuration.store [ "foo", "value" ];
  Alcotest.(
    check
      (option string)
      "existing"
      (Sihl.Configuration.read_string "foo")
      (Some "value"));
  Lwt.return ()
;;

let read_updated _ () =
  Sihl.Configuration.store [ "foo", "value" ];
  Sihl.Configuration.store [ "foo", "bar" ];
  Alcotest.(
    check
      (option string)
      "updated"
      (Sihl.Configuration.read_string "foo")
      (Some "bar"));
  Lwt.return ()
;;

type config =
  { username : string
  ; port : int option
  ; start_tls : bool
  ; ca_path : string option
  }

let config username port start_tls ca_path =
  { username; port; start_tls; ca_path }
;;

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
  Sihl.Configuration.store
    [ "SMTP_PORT", "1234"
    ; "SMTP_START_TLS", "true"
    ; "SMTP_CA_PATH", "/ca/file"
    ];
  Alcotest.check_raises
    "raises"
    (Sihl.Configuration.Exception "Invalid configuration provided")
    (fun () -> Sihl.Configuration.read schema |> ignore);
  Lwt.return ()
;;

let read_schema _ () =
  Sihl.Configuration.store
    [ "SMTP_USERNAME", "username"
    ; "SMTP_PORT", "1234"
    ; "SMTP_START_TLS", "true"
    ; "SMTP_CA_PATH", "/ca/file"
    ];
  Alcotest.(
    check
      testable_config
      "raises"
      (Sihl.Configuration.read schema)
      { username = "username"
      ; port = Some 1234
      ; start_tls = true
      ; ca_path = Some "/ca/file"
      });
  Lwt.return ()
;;

let read_env_file_non_existing _ () =
  let data = Sihl.Configuration.read_env_file () in
  let data = Option.value data ~default:[] in
  Alcotest.(check (list string) "Returns empty keys" [] (List.map fst data));
  Alcotest.(check (list string) "Returns empty values" [] (List.map snd data));
  Unix.putenv "ROOT_PATH" "";
  Lwt.return ()
;;

let read_env_file switch () =
  let%lwt cur = Lwt_unix.getcwd () in
  let filename = cur ^ "/.env.test" in
  Lwt_switch.add_hook (Some switch) (fun () -> Lwt_unix.unlink filename);
  let keys = [ "NAME"; "OCCUPATION"; "AGE" ] in
  let values = [ "church"; "mathematician"; "92" ] in
  let%lwt () =
    Lwt_io.with_file ~mode:Lwt_io.Output filename (fun ch ->
        let envs = List.map2 (fun k v -> k ^ "=" ^ v) keys values in
        Lwt_list.iter_s (Lwt_io.write_line ch) envs)
  in
  let data = Sihl.Configuration.read_env_file () in
  let data = Option.value data ~default:[] in
  Alcotest.(
    check (slist string compare) "Returns keys" keys (List.map fst data));
  Alcotest.(
    check (slist string compare) "Returns values" values (List.map snd data));
  Lwt.return ()
;;

module Test1 : sig
  val require_succeeds : 'a -> unit -> unit Lwt.t
end = struct
  type t =
    { hey : int
    ; is : bool option
    }

  let t hey is = { hey; is }

  let schema =
    let open Conformist in
    make [ int "hey"; optional (bool ~default:true "is") ] t
  ;;

  let require_succeeds _ () =
    let data = [ "hey", "123" ] in
    Sihl.Configuration.store data;
    Sihl.Configuration.require schema;
    Lwt.return ()
  ;;
end

module Test2 : sig
  val require_fails : 'a -> unit -> unit Lwt.t
end = struct
  type t = { ho : int }

  let t ho = { ho }

  let schema =
    let open Conformist in
    make [ int "ho" ] t
  ;;

  let require_fails _ () =
    let data = [ "ho", "value" ] in
    Sihl.Configuration.store data;
    let exc = Sihl.Configuration.Exception "Invalid configuration provided" in
    Alcotest.(
      check_raises "raises" exc (fun () -> Sihl.Configuration.require schema));
    Lwt.return ()
  ;;
end

let suite =
  Alcotest_lwt.
    [ ( "service configuration"
      , [ test_case "read empty" `Quick read_empty_value
        ; test_case "read non-existing" `Quick read_non_existing
        ; test_case "read existing" `Quick read_existing
        ; test_case "read schema invalid" `Quick read_schema_invalid
        ; test_case "read schema" `Quick read_schema
        ; test_case
            "read env file non-existing"
            `Quick
            read_env_file_non_existing
        ; test_case "read env file" `Quick read_env_file
        ; test_case "require succeeds" `Quick Test1.require_succeeds
        ; test_case "require fails" `Quick Test2.require_fails
        ] )
    ]
;;

let () =
  Unix.putenv "SIHL_ENV" "test";
  Lwt_main.run (Alcotest_lwt.run "configuration" suite)
;;
