open Base

let ( let* ) = Lwt.bind

let cookie_key = "session_key"

let m () =
  let filter handler ctx =
    match Web_req.cookie_data ctx ~key:cookie_key with
    | Some session_key -> (
        let* session = Session.get_session ctx ~key:session_key in
        let session = session |> Result.ok_or_failwith in
        (* TODO move most of the logic into session service *)
        match session with
        | Some session ->
            let* session =
              if Session.is_expired (Ptime_clock.now ()) session then (
                Logs.debug (fun m ->
                    m "SESSION: Session expired, creating new one");
                let session = Session.create (Ptime_clock.now ()) in
                (* TODO try to create new session if key is already taken *)
                let* result = Session.insert_session ctx ~session in
                let () = result |> Result.ok_or_failwith in
                Lwt.return session )
              else Lwt.return session
            in
            let ctx = Session.add_to_ctx session ctx in
            handler ctx
        | None ->
            let session = Session.create (Ptime_clock.now ()) in
            (* TODO try to create new session if key is already taken *)
            let* result = Session.insert_session ctx ~session in
            let () = result |> Result.ok_or_failwith in
            let ctx = Session.add_to_ctx session ctx in
            let* res = handler ctx in
            res
            |> Web_res.set_cookie ~key:cookie_key ~data:session.key
            |> Lwt.return )
    | None ->
        let session = Session.create (Ptime_clock.now ()) in
        (* TODO try to create new session if key is already taken *)
        let* result = Session.insert_session ctx ~session in
        let () = result |> Result.ok_or_failwith in
        let ctx = Session.add_to_ctx session ctx in
        let* res = handler ctx in
        res
        |> Web_res.set_cookie ~key:cookie_key ~data:session.key
        |> Lwt.return
  in
  Web_middleware_core.create ~name:"session" filter
