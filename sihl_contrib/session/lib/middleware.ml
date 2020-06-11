open Base

let ( let* ) = Lwt.bind

let cookie_key = "session.key"

let hmap_key : string Opium.Hmap.key =
  Opium.Hmap.Key.create ("session.key", fun _ -> sexp_of_string "session.key")

let session () =
  let filter handler req =
    let (module Repository : Repo.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in
    match Opium.Std.Cookie.get req ~key:cookie_key with
    | Some session_key -> (
        let* session =
          Repository.get ~key:session_key |> Sihl.Core.Db.query_db_exn req
        in
        match session with
        | Some session ->
            let* session =
              if Sihl.Session.is_expired (Ptime_clock.now ()) session then
                let () =
                  Logs.debug (fun m ->
                      m "SESSION: Session expired, creating new one")
                in
                let session = Sihl.Session.create (Ptime_clock.now ()) in
                (* TODO try to create new session if key is already taken *)
                let* () =
                  Repository.insert session |> Sihl.Core.Db.query_db_exn req
                in
                Lwt.return session
              else Lwt.return session
            in
            let env =
              Opium.Hmap.add hmap_key (Sihl.Session.key session)
                (Opium.Std.Request.env req)
            in
            handler { req with env }
        | None ->
            let session = Sihl.Session.create (Ptime_clock.now ()) in
            (* TODO try to create new session if key is already taken *)
            let* () =
              Repository.insert session |> Sihl.Core.Db.query_db_exn req
            in
            let env =
              Opium.Hmap.add hmap_key (Sihl.Session.key session)
                (Opium.Std.Request.env req)
            in
            let* res = handler { req with env } in
            res
            |> Sihl.Http.Cookie.set ~key:cookie_key ~data:session.key
            |> Lwt.return )
    | None ->
        let session = Sihl.Session.create (Ptime_clock.now ()) in
        (* TODO try to create new session if key is already taken *)
        let* () = Repository.insert session |> Sihl.Core.Db.query_db_exn req in
        let env =
          Opium.Hmap.add hmap_key (Sihl.Session.key session)
            (Opium.Std.Request.env req)
        in
        let* resp = handler { req with env } in
        resp
        |> Sihl.Http.Cookie.set ~key:cookie_key ~data:session.key
        |> Lwt.return
  in
  Opium.Std.Rock.Middleware.create ~name:"session" ~filter
