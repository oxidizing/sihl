open Base
open Lwt.Syntax

let run_forever () =
  let p, _ = Lwt.wait () in
  p

let registered_endpoints : Web_server_core.endpoint list ref = ref []

(* This is all the Opium & Cohttp specific stuff, it has to
   live in the service implementation, so swapping web server services
   is easy *)
let res_to_opium res =
  match Web_res.opium_res res with
  | Some res -> Lwt.return res
  | None -> (
      let headers = res |> Web_res.headers |> Cohttp.Header.of_list in
      let headers =
        Cohttp.Header.add headers "Content-Type"
          (Web_core.show_content_type (Web_res.content_type res))
      in
      let code = res |> Web_res.status |> Cohttp.Code.status_of_code in
      let headers =
        match Web_res.redirect_path res with
        | Some path -> Cohttp.Header.add headers "Location" path
        | None -> headers
      in
      let cookie_headers =
        res |> Web_res.cookies
        |> List.map ~f:(fun cookie ->
               Cohttp.Cookie.Set_cookie_hdr.make ~secure:false ~path:"/" cookie)
        |> List.map ~f:Cohttp.Cookie.Set_cookie_hdr.serialize
      in
      let headers =
        List.fold_left cookie_headers ~init:headers ~f:(fun headers (k, v) ->
            Cohttp.Header.add headers k v)
      in
      match Web_res.body res with
      | None -> Opium.Std.respond ~headers ~code (`String "") |> Lwt.return
      | Some (Web_res.String body) ->
          Opium.Std.respond ~headers ~code (`String body) |> Lwt.return
      | Some (File_path fname) ->
          let* cohttp_response =
            Cohttp_lwt_unix.Server.respond_file ~headers ~fname ()
          in
          Opium_kernel.Rock.Response.of_response_body cohttp_response
          |> Lwt.return )

let handler_to_opium_handler handler opium_req =
  let* handler = Core.Ctx.empty |> Web_req.add_to_ctx opium_req |> handler in
  handler |> res_to_opium

let to_opium_builder route =
  let meth = Web_route.meth route in
  let path = Web_route.path route in
  let handler = Web_route.handler route in
  let handler = handler_to_opium_handler handler in
  match meth with
  | Get -> Opium.Std.get path handler
  | Post -> Opium.Std.post path handler
  | Put -> Opium.Std.put path handler
  | Delete -> Opium.Std.delete path handler
  | All -> Opium.Std.all path handler

let endpoints_to_opium_builders endpoints =
  endpoints
  |> List.map ~f:(fun (prefix, routes, middleware_stack) ->
         routes
         |> List.map ~f:(Web_route.prefix prefix)
         |> List.map ~f:(Web_middleware.apply_stack middleware_stack)
         |> List.map ~f:to_opium_builder)
  |> List.concat

module MakeOpium (Log : Log.Sig.SERVICE) (CmdService : Cmd.Sig.SERVICE) :
  Web_server_sig.SERVICE = struct
  let start_server _ =
    Log.debug (fun m -> m "WEB: Starting HTTP server");
    let app = Opium.Std.App.(empty |> port 3000 |> cmd_name "Sihl App") in
    let builders = endpoints_to_opium_builders !registered_endpoints in
    let app =
      List.fold ~f:(fun app builder -> builder app) ~init:app builders
    in
    (* We don't want to block here, the returned Lwt.t will never resolve *)
    let _ = Opium.Std.App.start app in
    run_forever ()

  let lifecycle =
    Core.Container.Lifecycle.make "web-server"
      ~dependencies:[ Log.lifecycle; CmdService.lifecycle ]
      (fun ctx -> Lwt.return ctx)
      (fun _ -> Lwt.return ())

  let register_endpoints routes = registered_endpoints := routes
end
