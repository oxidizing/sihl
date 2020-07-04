module Service : Web_server_sig.SERVICE = struct
  let on_bind _ = Lwt_result.return ()

  let on_start _ =
    (* TODO
       Start web server *)
    Lwt_result.return ()

  let on_stop _ = Lwt_result.return ()

  let register_routes _ _ = failwith "TODO register_routes"

  (*
   *   let merge_endpoints project =
   *     project.apps
   *     |> List.map ~f:(fun (module App : APP) -> App.endpoints ())
   *     |> List.concat
   *
   *   let add_builders builders app =
   *     List.fold ~f:(fun app builder -> builder app) ~init:app builders
   *
   *   let start_http_server project =
   *     let endpoints = merge_endpoints project in
   *     let middlewares =
   *       List.map ~f:(fun m -> Opium.Std.middleware @@ m ()) project.middlewares
   *     in
   *     let port = Config.read_int ~default:3000 "PORT" in
   *     Logs.debug (fun m -> m "START: Http server starting on port %i" port);
   *
   *     let app =
   *       Opium.Std.App.empty |> Opium.Std.App.port port
   *       |> Opium.Std.App.cmd_name "Sihl Project"
   *       |> add_builders middlewares |> add_builders endpoints
   *     in
   *     (\* detaching from the thread so tests can run in the same process *\)
   *     let _ = Opium.Std.App.start app in
   *     Logs.debug (fun m -> m "START: Http server started");
   *     Lwt.return @@ Ok ()
   *)
end

let instance =
  Core.Container.create_binding Web_server_sig.key
    (module Service)
    (module Service)
