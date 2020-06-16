open Http
open Base

let ( let* ) = Lwt_result.bind

let m () =
  let filter handler req =
    let ( let* ) = Lwt.bind in
    let* res = Http.Res.try_run (fun () -> handler req) in
    match (Req.accepts_html req, res) with
    | _, Ok res -> Lwt.return @@ Ok res
    | false, Error error ->
        let msg = Core.Error.show error in
        Logs.err (fun m -> m "%s" msg);
        let headers =
          Cohttp.Header.of_list [ ("Content-Type", Req.content_type Json) ]
        in
        let body = Cohttp_lwt.Body.of_string @@ Res.Msg.msg_string msg in
        Opium.Std.Response.create ~headers ~body ~code:(Res.code_of_error error)
          ()
        |> Result.return |> Lwt.return
    | true, Error ((`Authentication _ | `Authorization _) as error) ->
        let ( let* ) = Lwt_result.bind in
        (* TODO evaluate whether the error handler
           should really remove invalid cookies *)
        (* TODO make custom permission/not authenticated
           error page configurable *)
        let msg = Http.Res.error_to_msg error in
        let* () = Middleware_flash.set_error req msg in
        Logs.err (fun m -> m "%s" msg);
        let headers =
          Cohttp.Header.of_list
            [
              ("Content-Type", Req.content_type Html);
              ("Location", "/admin/login/");
            ]
        in
        let body = Cohttp_lwt.Body.of_string @@ Res.Msg.msg_string msg in
        Opium.Std.Response.create ~headers ~body ~code:`Moved_permanently ()
        (* TODO move session cookie into http_session.ml *)
        |> Opium.Std.Cookie.set
             ~expiration:(`Max_age (Int64.of_int 0))
             ~http_only:true ~secure:false ~key:"session_id"
             ~data:"session_stopped"
        |> Result.return |> Lwt.return
    | true, Error ((`BadRequest _ | `NotFound _ | `Internal _) as error) ->
        let ( let* ) = Lwt_result.bind in
        let msg = Http.Res.error_to_msg error in
        let* () = Middleware_flash.set_error req msg in
        Logs.err (fun m -> m "%s" msg);
        let headers =
          Cohttp.Header.of_list
            (* TODO make custom error page configurable *)
            [ ("Content-Type", "text/html"); ("Location", "/admin/login/") ]
        in
        let body = Cohttp_lwt.Body.of_string @@ Res.Msg.msg_string msg in
        Opium.Std.Response.create ~headers ~body ~code:`Moved_permanently ()
        |> Result.return |> Lwt.return
  in
  Http.Middleware.create ~name:"error" ~filter
