open Base
open Lwt.Syntax
module Sig = Token_service_sig
module Repo = Token_service_repo

module Make
    (RandomService : Utils.Random.Service.Sig.SERVICE)
    (Repo : Sig.REPOSITORY) : Sig.SERVICE = struct
  let find_opt ctx value =
    let* token = Repo.find_opt ctx ~value in
    Lwt.return
    @@ Option.bind token ~f:(fun tk ->
           if Token_core.is_valid tk then token else None)

  let find ctx value =
    let* token = find_opt ctx value in
    match token with
    | Some token -> Lwt.return token
    | None ->
        raise
          (Token_core.Exception
             (Printf.sprintf "Token %s not found or not valid" value))

  let find_by_id_opt ctx id =
    let* token = Repo.find_by_id_opt ctx ~id in
    Lwt.return
    @@ Option.bind token ~f:(fun tk ->
           if Token_core.is_valid tk then token else None)

  let find_by_id ctx id =
    let* token = find_by_id_opt ctx id in
    match token with
    | Some token -> Lwt.return token
    | None ->
        raise
          (Token_core.Exception
             (Printf.sprintf "Token with id %s not found or not valid" id))

  let make ~id ~data ~kind ?(expires_in = Utils.Time.OneDay) ?now ?(length = 80)
      () =
    let value = RandomService.base64 ~bytes:length in
    let expires_in = Utils.Time.duration_to_span expires_in in
    let now = Option.value ~default:(Ptime_clock.now ()) now in
    let expires_at = Option.value_exn (Ptime.add_span now expires_in) in
    let status = Token_core.Status.Active in
    let created_at = Ptime_clock.now () in
    Token_core.make ~id ~value ~data ~kind ~status ~expires_at ~created_at

  let create ctx ~kind ?data ?expires_in ?length () =
    let expires_in = Option.value ~default:Utils.Time.OneDay expires_in in
    let length = Option.value ~default:80 length in
    let id = Data.Id.random () |> Data.Id.to_string in
    let token = make ~id ~kind ~data ~expires_in ~length () in
    let* () = Repo.insert ctx ~token in
    let value = Token_core.value token in
    find ctx value

  let invalidate ctx token =
    Repo.update ctx ~token:(Token_core.invalidate token)

  let start ctx =
    let () = Repo.register_migration () in
    let () = Repo.register_cleaner () in
    Lwt.return ctx

  let stop _ = Lwt.return ()

  let lifecycle = Core.Container.Lifecycle.create "token" ~start ~stop

  let configure configuration =
    let configuration = Core.Configuration.make configuration in
    Core.Container.Service.create ~configuration lifecycle
end
