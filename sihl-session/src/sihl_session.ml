let log_src = Logs.Src.create ("sihl.service." ^ Sihl_contract.Session.name)

module Logs = (val Logs.src_log log_src : Logs.LOG)

let session_key_nr_bytes = 20

module Make (Repo : Session_repo.Sig) : Sihl_contract.Session.Sig = struct
  let make ?expire_date now =
    let open Sihl_facade.Session in
    let expire_date =
      match expire_date, expiration_date now with
      | Some expire_date, _ -> expire_date
      | None, expire_date -> expire_date
    in
    Sihl_contract.Session.
      { key = Sihl_core.Random.base64 session_key_nr_bytes; expire_date }
  ;;

  let create data =
    let open Lwt.Syntax in
    let session = make (Ptime_clock.now ()) in
    let data_map = data |> List.to_seq |> Sihl_contract.Session.Map.of_seq in
    let* () = Repo.insert session data_map in
    let* session = Repo.find_opt session.key in
    match session with
    | Some session -> Lwt.return session
    | None ->
      raise
      @@ Sihl_contract.Session.Exception "Failed to insert created session"
  ;;

  let find_opt = Repo.find_opt

  let find key =
    let open Lwt.Syntax in
    let* session = Repo.find_opt key in
    match session with
    | Some session -> Lwt.return session
    | None ->
      Logs.err (fun m -> m "Session with key %s not found in database" key);
      raise (Sihl_contract.Session.Exception "Session not found")
  ;;

  let find_all = Repo.find_all

  let set_value session ~k ~v =
    let open Lwt.Syntax in
    let open Sihl_contract.Session in
    let session_key = session.key in
    match v with
    | Some v ->
      let* session = find session_key in
      let* data = Repo.find_data session in
      let updated_data = Map.add k v data in
      Repo.update session updated_data
    | None ->
      let* session = find session_key in
      let* data = Repo.find_data session in
      let updated_data = Map.remove k data in
      Repo.update session updated_data
  ;;

  let find_value session k =
    let open Lwt.Syntax in
    let open Sihl_contract.Session in
    let session_key = session.key in
    let* session = find session_key in
    let* data = Repo.find_data session in
    Map.find_opt k data |> Lwt.return
  ;;

  (* Lifecycle *)

  let start () = Lwt.return ()
  let stop () = Lwt.return ()

  let lifecycle =
    Sihl_core.Container.Lifecycle.create
      Sihl_contract.Session.name
      ~dependencies:(fun () -> Repo.lifecycles)
      ~start
      ~stop
  ;;

  let register () =
    Repo.register_migration ();
    Repo.register_cleaner ();
    Sihl_core.Container.Service.create lifecycle
  ;;
end

module MigrationPostgreSql =
  Sihl_persistence.Migration.Make (Sihl_persistence.Migration_repo.PostgreSql)

module MigrationMariaDb =
  Sihl_persistence.Migration.Make (Sihl_persistence.Migration_repo.MariaDb)

module PostgreSql = Make (Session_repo.MakePostgreSql (MigrationPostgreSql))
module MariaDb = Make (Session_repo.MakeMariaDb (MigrationMariaDb))
