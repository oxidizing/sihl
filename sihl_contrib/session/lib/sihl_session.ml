module Model = Model
module Bind = Bind
module App = App
module Repo = Repo

let middleware = Middleware.session

let set ~key ~value req =
  let (module Repository : Repo.REPOSITORY) =
    Sihl.Core.Registry.get Bind.Repository.key
  in
  let session =
    match Opium.Hmap.find Middleware.hmap_key (Opium.Std.Request.env req) with
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
    match Opium.Hmap.find Middleware.hmap_key (Opium.Std.Request.env req) with
    | Some session -> session
    | None ->
        Sihl.Core.Err.raise_server
          "Session not found in Request.env, have you applied the \
           Sihl_session.middleware?"
  in
  Model.Session.get key session |> Lwt.return
