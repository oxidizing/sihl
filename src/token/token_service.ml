open Base
open Lwt.Syntax
module Repo = Token_service_repo

module Make (Log : Log_sig.SERVICE) (Repo : Token_sig.REPOSITORY) :
  Token_sig.SERVICE = struct
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

  let create ctx ~kind ?data ?expires_in () =
    let expires_in = Option.value ~default:Utils.Time.OneDay expires_in in
    let id = Data.Id.random () |> Data.Id.to_string in
    let token = Token_core.make ~id ~kind ~data ~expires_in () in
    let* () = Repo.insert ctx ~token in
    let value = Token_core.value token in
    find ctx value
end
