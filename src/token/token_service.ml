open Base
open Lwt.Syntax
module Sig = Token_service_sig
module Repo = Token_service_repo

module Make
    (Log : Log.Service.Sig.SERVICE)
    (RandomService : Utils.Random.Service.Sig.SERVICE)
    (Repo : Sig.REPOSITORY) : Sig.SERVICE = struct
  let lifecycle =
    Core.Container.Lifecycle.make "token"
      (fun ctx ->
        let () = Repo.register_migration () in
        let () = Repo.register_cleaner () in
        Lwt.return ctx)
      (fun _ -> Lwt.return ())

  let find_opt ctx value = Repo.find_opt ctx ~value

  let find ctx value =
    let* token = find_opt ctx value in
    match token with
    | Some token -> Lwt.return token
    | None ->
        raise (Token_core.Exception (Printf.sprintf "Token %s not found" value))

  let make ~id ~data ~kind ?(expires_in = Utils.Time.OneDay) ?now () =
    let value = RandomService.base64 ~bytes:80 in
    let expires_in = Utils.Time.duration_to_span expires_in in
    let now = Option.value ~default:(Ptime_clock.now ()) now in
    let expires_at = Option.value_exn (Ptime.add_span now expires_in) in
    let status = Token_core.Status.Active in
    let created_at = Ptime_clock.now () in
    Token_core.make ~id ~value ~data ~kind ~status ~expires_at ~created_at

  let create ctx ~kind ?data ?expires_in () =
    let expires_in = Option.value ~default:Utils.Time.OneDay expires_in in
    let id = Data.Id.random () |> Data.Id.to_string in
    let token = make ~id ~kind ~data ~expires_in () in
    let* () = Repo.insert ctx ~token in
    let value = Token_core.value token in
    find ctx value
end
