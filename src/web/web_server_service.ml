open Base

let ( let* ) = Lwt.bind

let registered_routes = ref []

let on_init _ = Lwt_result.return ()

let on_start _ =
  Logs.debug (fun m -> m "WEB: Starting HTTP server");
  let app = Opium.Std.App.(empty |> port 3000 |> cmd_name "Sihl App") in
  let builders =
    Web_server_core.stacked_routes_to_opium_builders !registered_routes
  in
  let app = List.fold ~f:(fun app builder -> builder app) ~init:app builders in
  (* We don't want to block here, the returned Lwt.t will never resolve *)
  let _ = Opium.Std.App.start app in
  Lwt_result.return ()

let on_stop _ = Lwt_result.return ()

let register_routes _ routes = Lwt_result.return (registered_routes := routes)
