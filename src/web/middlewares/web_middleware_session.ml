open Base

let ( let* ) = Lwt.bind

module Make (SessionService : Session.Sig.SERVICE) = struct
  let m ?(cookie_key = "session_key") () =
    let filter handler ctx =
      match Web_req.cookie_data ctx ~key:cookie_key with
      | Some session_key -> (
          let* session = SessionService.get_session ctx ~key:session_key in
          let session = session |> Result.ok_or_failwith in
          match session with
          | Some session ->
              let* session =
                if Session.is_expired (Ptime_clock.now ()) session then (
                  Logs.debug (fun m ->
                      m "SESSION: Session expired, creating new one");
                  let* session =
                    SessionService.create ctx []
                    |> Lwt.map Result.ok_or_failwith
                  in
                  Lwt.return session )
                else Lwt.return session
              in
              let ctx = Session.add_to_ctx session ctx in
              handler ctx
          | None ->
              let* session =
                SessionService.create ctx [] |> Lwt.map Result.ok_or_failwith
              in
              let ctx = Session.add_to_ctx session ctx in
              let* res = handler ctx in
              res
              |> Web_res.set_cookie ~key:cookie_key ~data:session.key
              |> Lwt.return )
      | None ->
          let* session =
            SessionService.create ctx [] |> Lwt.map Result.ok_or_failwith
          in
          let ctx = Session.add_to_ctx session ctx in
          let* res = handler ctx in
          res
          |> Web_res.set_cookie ~key:cookie_key ~data:session.key
          |> Lwt.return
    in
    Web_middleware_core.create ~name:"session" filter
end
