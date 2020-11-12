open Lwt.Syntax

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

  let lifecycle = Sihl.Core.Container.Lifecycle.create ~start ~stop "database"
  let register () = Sihl.Core.Container.Service.create lifecycle
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
    Sihl.Core.Container.Lifecycle.create
      "user service"
      ~start
      ~stop
      ~dependencies:[ Database.lifecycle ]
  ;;

  let ban =
    Sihl.Core.Command.make ~name:"ban" ~description:"Ban a user" (fun _ ->
        Lwt.return_unit)
  ;;

  let register () = Sihl.Core.Container.Service.create ~commands:[ ban ] lifecycle
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
    Sihl.Core.Container.Lifecycle.create
      "order service"
      ~start
      ~stop
      ~dependencies:[ Database.lifecycle ]
  ;;

  let order =
    Sihl.Core.Command.make ~name:"order" ~description:"Dispatch an order" (fun _ ->
        Lwt.return_unit)
  ;;

  let register () = Sihl.Core.Container.Service.create ~commands:[ order ] lifecycle
end

let run_user_command _ () =
  database_running := false;
  user_service_running := false;
  order_service_running := false;
  let set_config _ = Lwt.return @@ Unix.putenv "CREATE_ADMIN" "admin" in
  let* () =
    Sihl.Core.App.empty
    |> Sihl.Core.App.with_services [ UserService.register () ]
    |> Sihl.Core.App.before_start set_config
    |> Sihl.Core.App.run' ~args:[ "ban" ]
  in
  Alcotest.(check bool "database is running" !database_running true);
  Alcotest.(check bool "order service is not running" !order_service_running false);
  Alcotest.(check bool "user service is running" !user_service_running true);
  Lwt.return ()
;;

let run_order_command _ () =
  database_running := false;
  user_service_running := false;
  order_service_running := false;
  let set_config _ = Lwt.return @@ Unix.putenv "ORDER_NOTIFICATION_URL" "https://" in
  let* () =
    Sihl.Core.App.empty
    |> Sihl.Core.App.with_services [ OrderService.register () ]
    |> Sihl.Core.App.before_start set_config
    |> Sihl.Core.App.run' ~args:[ "order" ]
  in
  Alcotest.(check bool "database is running" !database_running true);
  Alcotest.(check bool "order service is running" !order_service_running true);
  Alcotest.(check bool "user service is not running" !user_service_running false);
  Lwt.return ()
;;
