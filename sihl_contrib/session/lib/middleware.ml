let ( let* ) = Lwt.bind

let cookie_key = "sessions_session_id"

let session () app =
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
        Logs.debug (fun m -> m "no session cookie found");
        (* TODO
               1. generate new session, store it in db
               2. send cookie with session id
        *)
        let session = Model.Session.create () in
        Logs.debug (fun m -> m "inserting session");
        let* () = Repository.insert session |> Sihl.Core.Db.query_db_exn req in
        Logs.debug (fun m -> m "session inserted");
        handler req
  in
  let m = Opium.Std.Rock.Middleware.create ~name:"session" ~filter in
  Opium.Std.middleware m app
