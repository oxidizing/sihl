open Base

let ( let* ) = Lwt_result.bind

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
          Repository.get ~key:session_key |> Sihl.Core.Db.query_db req
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
                  Repository.insert session |> Sihl.Core.Db.query_db req
                in
                session |> Result.return |> Lwt.return
              else session |> Result.return |> Lwt.return
            in
            let env =
              Opium.Hmap.add hmap_key (Sihl.Session.key session)
                (Opium.Std.Request.env req)
            in
            handler { req with env } |> Lwt.map Result.return
        | None ->
            let session = Sihl.Session.create (Ptime_clock.now ()) in
            (* TODO try to create new session if key is already taken *)
            let* () = Repository.insert session |> Sihl.Core.Db.query_db req in
            let env =
              Opium.Hmap.add hmap_key (Sihl.Session.key session)
                (Opium.Std.Request.env req)
            in
            let* res = handler { req with env } |> Lwt.map Result.return in
            res
            |> Sihl.Http.Cookie.set ~key:cookie_key ~data:session.key
            |> Result.return |> Lwt.return )
    | None ->
        let session = Sihl.Session.create (Ptime_clock.now ()) in
        (* TODO try to create new session if key is already taken *)
        let* () = Repository.insert session |> Sihl.Core.Db.query_db req in
        let env =
          Opium.Hmap.add hmap_key (Sihl.Session.key session)
            (Opium.Std.Request.env req)
        in
        let* resp = handler { req with env } |> Lwt.map Result.return in
        resp
        |> Sihl.Http.Cookie.set ~key:cookie_key ~data:session.key
        |> Result.return |> Lwt.return
  in
  Sihl.Http.Middleware.create ~name:"session" ~filter
