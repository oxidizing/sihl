open Base

let ( let* ) = Lwt.bind

let cookie_key = "session.key"

let m () =
  let filter handler req =
    let ctx = Web_req.ctx_of req in
    match Opium.Std.Cookie.get req ~key:cookie_key with
    | Some session_key -> (
        let* session = Session.get_session ctx ~key:session_key in
        let session = session |> Result.ok_or_failwith in
        match session with
        | Some session ->
            let* session =
              if Session.is_expired (Ptime_clock.now ()) session then
                let () =
                  Logs.debug (fun m ->
                      m "SESSION: Session expired, creating new one")
                in
                let session = Session.create (Ptime_clock.now ()) in
                (* TODO try to create new session if key is already taken *)
                let* result = Session.insert_session ctx ~session in
                let () = result |> Result.ok_or_failwith in
                Lwt.return session
              else Lwt.return session
            in
            let env =
              Opium.Hmap.add Session.Sig.middleware_key (Session.key session)
                (Opium.Std.Request.env req)
            in
            handler { req with env }
        | None ->
            let session = Session.create (Ptime_clock.now ()) in
            (* TODO try to create new session if key is already taken *)
            let* result = Session.insert_session ctx ~session in
            let () = result |> Result.ok_or_failwith in
            let env =
              Opium.Hmap.add Session.Sig.middleware_key (Session.key session)
                (Opium.Std.Request.env req)
            in
            let* res = handler { req with env } in
            res
            |> Web_res.set_cookie ~key:cookie_key ~data:session.key
            |> Lwt.return )
    | None ->
        let session = Session.create (Ptime_clock.now ()) in
        (* TODO try to create new session if key is already taken *)
        let* result = Session.insert_session ctx ~session in
        let () = result |> Result.ok_or_failwith in
        let env =
          Opium.Hmap.add Session.Sig.middleware_key (Session.key session)
            (Opium.Std.Request.env req)
        in
        let* resp = handler { req with env } in
        resp
        |> Web_res.set_cookie ~key:cookie_key ~data:session.key
        |> Lwt.return
  in
  Opium.Std.Rock.Middleware.create ~name:"session" ~filter
