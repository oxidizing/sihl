module Core = Sihl_core
open Lwt.Syntax

let log_src = Logs.Src.create ~doc:"session" "sihl.service.session"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let ctx_key : string Core.Ctx.key = Core.Ctx.create_key ()

module Repo = Repo

module Make (Repo : Sig.REPO) : Sig.SERVICE = struct
  let make ?expire_date now =
    let open Model in
    match expire_date, default_expiration_date now with
    | Some expire_date, _ ->
      Some { key = Core.Random.base64 ~nr:10; data = Map.empty; expire_date }
    | None, Some expire_date ->
      Some { key = Core.Random.base64 ~nr:10; data = Map.empty; expire_date }
    | None, None -> None
  ;;

  let create ctx data =
    let empty_session =
      match make (Ptime_clock.now ()) with
      | Some session -> session
      | None ->
        Logs.err (fun m ->
            m "SESSION: Can not create session, failed to create validity time");
        raise (Model.Exception "Can not set session validity time")
    in
    let session =
      List.fold_left
        (fun session (key, value) -> Model.set ~key ~value session)
        empty_session
        data
    in
    let* () = Repo.insert ctx session in
    Lwt.return session
  ;;

  let find_opt = Repo.find_opt

  let find ctx ~key =
    let* session = Repo.find_opt ctx ~key in
    match session with
    | Some session -> Lwt.return session
    | None ->
      Logs.err (fun m -> m "SESSION: Session with key %s not found in database" key);
      raise (Model.Exception "Session not found")
  ;;

  let find_all = Repo.find_all

  let set ctx session ~key ~value =
    let session_key = Model.key session in
    let* session = find ctx ~key:session_key in
    let session = Model.set ~key ~value session in
    Repo.update ctx session
  ;;

  let unset ctx session ~key =
    let session_key = Model.key session in
    let* session = find ctx ~key:session_key in
    let session = Model.remove ~key session in
    Repo.update ctx session
  ;;

  let get ctx session ~key =
    let session_key = Model.key session in
    let* session = find ctx ~key:session_key in
    Model.get key session |> Lwt.return
  ;;

  let start ctx =
    Repo.register_migration ();
    Repo.register_cleaner ();
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()
  let lifecycle = Core.Container.Lifecycle.create "session" ~start ~stop

  let configure configuration =
    let configuration = Core.Configuration.make configuration in
    Core.Container.Service.create ~configuration lifecycle
  ;;
end
