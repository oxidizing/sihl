module Utils = Sihl_utils
module Core = Sihl_core
module Database = Sihl_database
open Lwt.Syntax

let log_src = Logs.Src.create "sihl.service.token"

module Logs = (val Logs.src_log log_src : Logs.LOG)

module Make (Repo : Sig.REPOSITORY) : Sig.SERVICE = struct
  let find_opt value =
    let* token = Repo.find_opt ~value in
    Lwt.return @@ Option.bind token (fun tk -> if Model.is_valid tk then token else None)
  ;;

  let find value =
    let* token = find_opt value in
    match token with
    | Some token -> Lwt.return token
    | None ->
      raise (Model.Exception (Printf.sprintf "Token %s not found or not valid" value))
  ;;

  let find_by_id_opt id =
    let* token = Repo.find_by_id_opt ~id in
    Lwt.return @@ Option.bind token (fun tk -> if Model.is_valid tk then token else None)
  ;;

  let find_by_id id =
    let* token = find_by_id_opt id in
    match token with
    | Some token -> Lwt.return token
    | None ->
      raise
        (Model.Exception (Printf.sprintf "Token with id %s not found or not valid" id))
  ;;

  let make ~id ~data ~kind ?(expires_in = Utils.Time.OneDay) ?now ?(length = 80) () =
    let value = Core.Random.base64 ~nr:length in
    let expires_in = Utils.Time.duration_to_span expires_in in
    let now = Option.value ~default:(Ptime_clock.now ()) now in
    let expires_at =
      match Ptime.add_span now expires_in with
      | Some expires_at -> expires_at
      | None -> failwith ("Could not parse expiry date for token with id " ^ id)
    in
    let status = Model.Status.Active in
    let created_at = Ptime_clock.now () in
    Model.make ~id ~value ~data ~kind ~status ~expires_at ~created_at
  ;;

  let create ~kind ?data ?expires_in ?length () =
    let expires_in = Option.value ~default:Utils.Time.OneDay expires_in in
    let length = Option.value ~default:80 length in
    let id = Database.Id.random () |> Database.Id.to_string in
    let token = make ~id ~kind ~data ~expires_in ~length () in
    let* () = Repo.insert ~token in
    let value = Model.value token in
    find value
  ;;

  let invalidate token = Repo.update ~token:(Model.invalidate token)

  let start () =
    let () = Repo.register_migration () in
    let () = Repo.register_cleaner () in
    Lwt.return ()
  ;;

  let stop _ = Lwt.return ()
  let lifecycle = Core.Container.Lifecycle.create ~dependencies:[] "token" ~start ~stop
  let register () = Core.Container.Service.create lifecycle
end
