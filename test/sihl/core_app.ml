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

  let configure configuration =
    let configuration = Core.Configuration.make configuration in
    Core.Container.Service.create ~configuration lifecycle
  ;;
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
    Core.Command.make ~name:"ban" ~description:"Ban a user" (fun _ -> Lwt.return_unit)
  ;;

  let configure configuration =
    let configuration = Core.Configuration.make configuration in
    Core.Container.Service.create ~configuration ~commands:[ ban ] lifecycle
  ;;
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
    Core.Command.make ~name:"order" ~description:"Dispatch an order" (fun _ ->
        Lwt.return_unit)
  ;;

  let configure configuration =
    let configuration = Core.Configuration.make configuration in
    Core.Container.Service.create ~configuration ~commands:[ order ] lifecycle
  ;;
end

let run_user_command _ () =
  database_running := false;
  user_service_running := false;
  order_service_running := false;
  Sihl.Core.App.empty
  |> Sihl.Core.App.with_services [ UserService.configure [ "CREATE_ADMIN", "admin" ] ]
  |> Sihl.Core.App.run ~args:[ "ban" ];
  Alcotest.(check bool "database is running" !database_running true);
  Alcotest.(check bool "order service is not running" !order_service_running false);
  Alcotest.(check bool "user service is running" !user_service_running true);
  Lwt.return ()
;;

let run_order_command _ () =
  database_running := false;
  user_service_running := false;
  order_service_running := false;
  Sihl.Core.App.empty
  |> Sihl.Core.App.with_services
       [ OrderService.configure [ "ORDER_NOTIFICATION_URL", "https://" ] ]
  |> Sihl.Core.App.run ~args:[ "order" ];
  Alcotest.(check bool "database is running" !database_running true);
  Alcotest.(check bool "order service is running" !order_service_running true);
  Alcotest.(check bool "user service is not running" !user_service_running false);
  Lwt.return ()
;;
