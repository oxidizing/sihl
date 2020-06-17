open Base

let ( let* ) = Lwt_result.bind

let set ~key ~value req =
  let (module Repository : Repo.REPOSITORY) =
    Sihl.Core.Registry.get Bind.Repository.key
  in
  let session_key =
    match Opium.Hmap.find Middleware.hmap_key (Opium.Std.Request.env req) with
    | Some session -> session
    | None ->
        Sihl.Core.Err.raise_server
          "Session not found in Request.env, have you applied the \
           Sihl_session.middleware?"
  in
  let* session = Repository.get ~key:session_key |> Sihl.Core.Db.query_db req in
  match session with
  | None ->
      Logs.warn (fun m ->
          m "SESSION: Provided session key has no session in DB");
      Lwt.return @@ Error (Sihl.Error.authentication ())
  | Some session ->
      let session = Sihl.Session.set ~key ~value session in
      Repository.insert session |> Sihl.Core.Db.query_db req

let remove ~key req =
  let (module Repository : Repo.REPOSITORY) =
    Sihl.Core.Registry.get Bind.Repository.key
  in
  let session_key =
    match Opium.Hmap.find Middleware.hmap_key (Opium.Std.Request.env req) with
    | Some session -> session
    | None ->
        Sihl.Core.Err.raise_server
          "Session not found in Request.env, have you applied the \
           Sihl_session.middleware?"
  in
  let* session = Repository.get ~key:session_key |> Sihl.Core.Db.query_db req in
  match session with
  | None ->
      Logs.warn (fun m ->
          m "SESSION: Provided session key has no session in DB");
      Lwt.return @@ Error (Sihl.Error.authentication ())
  | Some session ->
      let session = Sihl.Session.remove ~key session in
      Repository.insert session |> Sihl.Core.Db.query_db req

let get key req =
  let (module Repository : Repo.REPOSITORY) =
    Sihl.Core.Registry.get Bind.Repository.key
  in
  let session_key =
    match Opium.Hmap.find Middleware.hmap_key (Opium.Std.Request.env req) with
    | Some session -> session
    | None ->
        Sihl.Core.Err.raise_server
          "Session not found in Request.env, have you applied the \
           Sihl_session.middleware?"
  in
  let* session = Repository.get ~key:session_key |> Sihl.Core.Db.query_db req in
  match session with
  | None ->
      Logs.warn (fun m ->
          m "SESSION: Provided session key has no session in DB");
      Lwt.return @@ Ok None
  | Some session -> Sihl.Session.get key session |> Result.return |> Lwt.return
