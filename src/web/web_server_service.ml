open Base

let ( let* ) = Lwt.bind

let run_forever () =
  let p, _ = Lwt.wait () in
  p

let registered_routes : Web_server_core.stacked_routes ref = ref []

module Make (CmdService : Cmd.Sig.SERVICE) : Web_server_sig.SERVICE = struct
  let start_server _ =
    Logs.debug (fun m -> m "WEB: Starting HTTP server");
    let app = Opium.Std.App.(empty |> port 3000 |> cmd_name "Sihl App") in
    let builders =
      Web_server_core.stacked_routes_to_opium_builders !registered_routes
    in
    let app =
      List.fold ~f:(fun app builder -> builder app) ~init:app builders
    in
    (* We don't want to block here, the returned Lwt.t will never resolve *)
    let _ = Opium.Std.App.start app in
    run_forever ()

  let lifecycle =
    Core.Container.Lifecycle.make "webserver"
      ~dependencies:[ CmdService.lifecycle ]
      (fun ctx -> Lwt.return ctx)
      (fun _ -> Lwt.return ())

  let register_routes _ routes = Lwt_result.return (registered_routes := routes)
end
