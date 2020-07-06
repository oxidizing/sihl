let ( let* ) = Lwt.bind

let m () =
  let filter handler req =
    handler req
    (* let ctx = Http.ctx req in
     * let* response = Core_err.try_to_run (fun () -> handler req) in
     * match (Req.accepts_html req, response) with
     * | _, Ok response -> Lwt.return response
     * | false, Error error ->
     *     let msg = Core_err.Error.show error in
     *     Logs.err (fun m -> m "%s" msg);
     *     let headers =
     *       Cohttp.Header.of_list [ ("Content-Type", Req.content_type Json) ]
     *     in
     *     let body = Cohttp_lwt.Body.of_string @@ Res.Msg.msg_string msg in
     *     Opium.Std.Response.create ~headers ~body ~code:(Res.code_of_error error)
     *       ()
     *     |> Lwt.return
     * | ( true,
     *     Error
     *       ( Core_err.Error.NotAuthenticated msg
     *       | Core_err.Error.NoPermissions msg ) ) ->
     *     (\* TODO evaluate whether the error handler should really remove invalid cookies *\)
     *     let* () =
     *       Middleware_flash.set_error ctx msg
     *       |> Lwt.map Base.Result.ok_or_failwith
     *     in
     *     Logs.err (fun m -> m "%s" msg);
     *     (\* TODO make custom permission/not authenticated error page configurable *\)
     *     let headers =
     *       Cohttp.Header.of_list
     *         [
     *           ("Content-Type", Req.content_type Html);
     *           ("Location", "/admin/login/");
     *         ]
     *     in
     *     let body = Cohttp_lwt.Body.of_string @@ Res.Msg.msg_string msg in
     *     Opium.Std.Response.create ~headers ~body ~code:`Moved_permanently ()
     *     (\* TODO move session cookie into http_session.ml *\)
     *     |> Opium.Std.Cookie.set
     *          ~expiration:(`Max_age (Int64.of_int 0))
     *          ~http_only:true ~secure:false ~key:"session_id"
     *          ~data:"session_stopped"
     *     |> Lwt.return
     * | ( true,
     *     Error
     *       ( Core_err.Error.BadRequest msg
     *       | Core_err.Error.Configuration msg
     *       | Core_err.Error.Database msg
     *       | Core_err.Error.Email msg
     *       | Core_err.Error.Server msg ) ) ->
     *     let* () =
     *       Middleware_flash.set_error ctx msg
     *       |> Lwt.map Base.Result.ok_or_failwith
     *     in
     *     Logs.err (fun m -> m "%s" msg);
     *     let headers =
     *       Cohttp.Header.of_list
     *         (\* TODO make custom error page configurable *\)
     *         [ ("Content-Type", "text/html"); ("Location", "/admin/login/") ]
     *     in
     *     let body = Cohttp_lwt.Body.of_string @@ Res.Msg.msg_string msg in
     *     Opium.Std.Response.create ~headers ~body ~code:`Moved_permanently ()
     *     |> Lwt.return *)
  in
  Web_middleware_core.create ~name:"error handler" filter
