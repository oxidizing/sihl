open Base
open Lwt.Syntax

module Make (SessionService : Session.Service.Sig.SERVICE) = struct
  let m ?(cookie_key = "session_key") () =
    let filter handler ctx =
      match Http.Req.cookie_data ctx ~key:cookie_key with
      | Some session_key -> (
          (* A session cookie was found *)
          let* session = SessionService.find_opt ctx ~key:session_key in
          match session with
          | Some session ->
              let* session =
                if Session.is_expired (Ptime_clock.now ()) session then (
                  Logs.debug (fun m ->
                      m "SESSION: Session expired, creating new one");
                  let* session = SessionService.create ctx [] in
                  Lwt.return session )
                else Lwt.return session
              in
              let ctx = SessionService.add_to_ctx session ctx in
              handler ctx
          | None ->
              let* session = SessionService.create ctx [] in
              let ctx = SessionService.add_to_ctx session ctx in
              let* res = handler ctx in
              res
              |> Http.Res.set_cookie ~key:cookie_key ~data:session.key
              |> Lwt.return )
      | None ->
          (* No session cookie found *)
          let* session = SessionService.create ctx [] in
          let ctx = SessionService.add_to_ctx session ctx in
          let* res = handler ctx in
          res
          |> Http.Res.set_cookie ~key:cookie_key ~data:session.key
          |> Lwt.return
    in
    Middleware_core.create ~name:"session" filter
end
