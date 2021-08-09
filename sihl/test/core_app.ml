let database_running = ref false

module Database = struct
  let start ctx =
    print_endline "Starting database";
    database_running := true;
    Lwt.return ctx
  ;;

  let stop _ =
    database_running := false;
    Lwt.return ()
  ;;

  let lifecycle = Sihl.Container.create_lifecycle ~start ~stop "database"
  let register () = Sihl.Container.Service.create lifecycle
end

let user_service_running = ref false

module UserService = struct
  let start ctx =
    print_endline "Starting user service";
    user_service_running := true;
    Lwt.return ctx
  ;;

  let stop _ =
    user_service_running := false;
    Lwt.return ()
  ;;

  let lifecycle =
    Sihl.Container.create_lifecycle
      "user service"
      ~start
      ~stop
      ~dependencies:(fun () -> [ Database.lifecycle ])
  ;;

  let ban =
    Sihl.Command.make
      ~name:"ban"
      ~description:"Ban a user"
      ~dependencies:[ lifecycle ]
      (fun _ -> Lwt.return @@ Some ())
  ;;

  let register () = Sihl.Container.Service.create ~commands:[ ban ] lifecycle
end

let order_service_running = ref false

module OrderService = struct
  let start ctx =
    print_endline "Starting order service";
    order_service_running := true;
    Lwt.return ctx
  ;;

  let stop _ =
    order_service_running := false;
    Lwt.return ()
  ;;

  let lifecycle =
    Sihl.Container.create_lifecycle
      "order service"
      ~start
      ~stop
      ~dependencies:(fun () -> [ Database.lifecycle ])
  ;;

  let order =
    Sihl.Command.make
      ~name:"order"
      ~description:"Dispatch an order"
      ~dependencies:[ lifecycle ]
      (fun _ -> Lwt.return @@ Some ())
  ;;

  let register () = Sihl.Container.Service.create ~commands:[ order ] lifecycle
end

let email1_service_running = ref false

module Email1Service = struct
  let start ctx =
    print_endline "Starting email1 service";
    email1_service_running := true;
    Lwt.return ctx
  ;;

  let stop _ =
    email1_service_running := false;
    Lwt.return ()
  ;;

  let lifecycle =
    Sihl.Container.create_lifecycle
      "email service"
      ~implementation_name:"email1"
      ~start
      ~stop
      ~dependencies:(fun () -> [ Database.lifecycle ])
  ;;

  let register () = Sihl.Container.Service.create lifecycle
end

let email2_service_running = ref false

module Email2Service = struct
  let start ctx =
    print_endline "Starting email2 service";
    email2_service_running := true;
    Lwt.return ctx
  ;;

  let stop _ =
    email2_service_running := false;
    Lwt.return ()
  ;;

  let lifecycle =
    Sihl.Container.create_lifecycle
      "email service"
      ~implementation_name:"email2"
      ~start
      ~stop
      ~dependencies:(fun () -> [ Email1Service.lifecycle; Database.lifecycle ])
  ;;

  let send =
    Sihl.Command.make
      ~name:"send"
      ~description:"Send an email"
      ~dependencies:[ lifecycle ]
      (fun _ -> Lwt.return @@ Some ())
  ;;

  let register () = Sihl.Container.Service.create ~commands:[ send ] lifecycle
end

let run_user_command _ () =
  database_running := false;
  user_service_running := false;
  order_service_running := false;
  let set_config _ = Lwt.return @@ Unix.putenv "CREATE_ADMIN" "admin" in
  let%lwt () =
    Sihl.App.empty
    |> Sihl.App.with_services [ UserService.register () ]
    |> Sihl.App.before_start set_config
    |> Sihl.App.run' ~args:[ "ban" ] ~log_reporter:Logs.nop_reporter
  in
  Alcotest.(check bool "database is running" !database_running true);
  Alcotest.(
    check bool "order service is not running" !order_service_running false);
  Alcotest.(check bool "user service is running" !user_service_running true);
  Lwt.return ()
;;

let run_order_command _ () =
  database_running := false;
  user_service_running := false;
  order_service_running := false;
  let set_config _ =
    Lwt.return @@ Unix.putenv "ORDER_NOTIFICATION_URL" "https://"
  in
  let%lwt () =
    Sihl.App.empty
    |> Sihl.App.with_services [ OrderService.register () ]
    |> Sihl.App.before_start set_config
    |> Sihl.App.run' ~args:[ "order" ] ~log_reporter:Logs.nop_reporter
  in
  Alcotest.(check bool "database is running" !database_running true);
  Alcotest.(check bool "order service is running" !order_service_running true);
  Alcotest.(
    check bool "user service is not running" !user_service_running false);
  Lwt.return ()
;;

let start_email_services _ () =
  database_running := false;
  email1_service_running := false;
  email2_service_running := false;
  let%lwt () =
    Sihl.App.empty
    |> Sihl.App.with_services
         [ Email2Service.register (); Email1Service.register () ]
    |> Sihl.App.run' ~args:[ "send" ] ~log_reporter:Logs.nop_reporter
  in
  Alcotest.(check bool "database is running" !database_running true);
  Alcotest.(check bool "email1 is running" !email1_service_running true);
  Alcotest.(check bool "email2 is running" !email2_service_running true);
  Lwt.return ()
;;

let suite =
  Alcotest_lwt.
    [ ( "app"
      , [ test_case "run user command" `Quick run_user_command
        ; test_case "run order command" `Quick run_order_command
        ; test_case "start email services" `Quick start_email_services
        ] )
    ]
;;

let () =
  Unix.putenv "SIHL_ENV" "test";
  Lwt_main.run (Alcotest_lwt.run "app" suite)
;;
