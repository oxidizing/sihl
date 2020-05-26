open Base

let ( let* ) = Lwt.bind

let cookie_key = "sessions_session_id"

let hmap_key : Model.Session.t Opium.Hmap.key =
  Opium.Hmap.Key.create ("session", fun _ -> sexp_of_string "session")

let session () =
  let filter handler req =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get Bind.Repository.key
    in
    match Opium.Std.Cookie.get req ~key:cookie_key with
    | Some session_key -> (
        let* session =
          Repository.get ~key:session_key |> Sihl.Core.Db.query_db_exn req
        in
        match session with
        | Some _ ->
            (* TODO
               1. fetch session data
               2. decode to (string * string) list
               3. put into env
            *)
            handler req
        | None ->
            (* TODO
                       1. generate new session, store it in db
                       2. send cookie with session id to override invalid cookie
            *)
            let session = Model.Session.create () in
            let* () =
              Repository.insert session |> Sihl.Core.Db.query_db_exn req
            in
            let* res = handler req in
            res
            |> Opium.Std.Cookie.set ~http_only:true ~secure:false
                 ~key:cookie_key
                 ~data:(Model.Session.key session)
            |> Lwt.return )
    | None ->
        let session = Model.Session.create () in
        let* () = Repository.insert session |> Sihl.Core.Db.query_db_exn req in
        let env = Opium.Hmap.add hmap_key session (Opium.Std.Request.env req) in
        let* resp = handler { req with env } in
        resp
        |> Sihl.Http.Cookie.set ~key:cookie_key ~data:session.key
        |> Lwt.return
  in
  Opium.Std.Rock.Middleware.create ~name:"session" ~filter

let set ~key ~value req =
  let (module Repository : Repo_sig.REPOSITORY) =
    Sihl.Core.Registry.get Bind.Repository.key
  in
  let session =
    match Opium.Hmap.find hmap_key (Opium.Std.Request.env req) with
    | Some session -> session
    | None ->
        Sihl.Core.Err.raise_server
          "Session not found in Request.env, have you applied the \
           Sihl_session.middleware?"
  in
  let session = Model.Session.set ~key ~value session in
  Repository.insert session |> Sihl.Core.Db.query_db_exn req

let get key req =
  let session =
    match Opium.Hmap.find hmap_key (Opium.Std.Request.env req) with
    | Some session -> session
    | None ->
        Sihl.Core.Err.raise_server
          "Session not found in Request.env, have you applied the \
           Sihl_session.middleware?"
  in
  Model.Session.get key session |> Lwt.return
