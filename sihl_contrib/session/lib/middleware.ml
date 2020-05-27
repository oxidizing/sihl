open Base

let ( let* ) = Lwt.bind

let cookie_key = "sessions_session_id"

let hmap_key : Model.Session.t Opium.Hmap.key =
  Opium.Hmap.Key.create ("session", fun _ -> sexp_of_string "session")

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
              if Model.Session.is_expired (Ptime_clock.now ()) session then
                let session = Model.Session.create (Ptime_clock.now ()) in
                let* () =
                  Repository.insert session |> Sihl.Core.Db.query_db_exn req
                in
                Lwt.return session
              else Lwt.return session
            in
            let env =
              Opium.Hmap.add hmap_key session (Opium.Std.Request.env req)
            in
            handler { req with env }
        | None ->
            let session = Model.Session.create (Ptime_clock.now ()) in
            let* () =
              Repository.insert session |> Sihl.Core.Db.query_db_exn req
            in
            let* res = handler req in
            res
            |> Sihl.Http.Cookie.set ~key:cookie_key ~data:session.key
            |> Lwt.return )
    | None ->
        let session = Model.Session.create (Ptime_clock.now ()) in
        let* () = Repository.insert session |> Sihl.Core.Db.query_db_exn req in
        let env = Opium.Hmap.add hmap_key session (Opium.Std.Request.env req) in
        let* resp = handler { req with env } in
        resp
        |> Sihl.Http.Cookie.set ~key:cookie_key ~data:session.key
        |> Lwt.return
  in
  Opium.Std.Rock.Middleware.create ~name:"session" ~filter
