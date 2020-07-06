open Base

let registered_routes = ref []

module Service : Web_server_sig.SERVICE = struct
  let on_bind _ = Lwt_result.return ()

  let on_start _ =
    Logs.debug (fun m -> m "WEB: Starting HTTP server");
    let app = Opium.Std.App.(empty |> port 3000 |> cmd_name "Sihl App") in
    let builders =
      Web_server_core.stacked_routes_to_opium_builders !registered_routes
    in
    let app =
      List.fold ~f:(fun app builder -> builder app) ~init:app builders
    in
    let _ = Opium.Std.App.start app in
    Lwt_result.return ()

  let on_stop _ = Lwt_result.return ()

  let register_routes _ routes = Lwt_result.return (registered_routes := routes)
end

let instance =
  Core.Container.create_binding Web_server_sig.key
    (module Service)
    (module Service)
