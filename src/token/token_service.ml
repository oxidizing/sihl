open Base
open Lwt.Syntax
module Repo = Token_service_repo

module Make (Db : Data_db_sig.SERVICE) (Repo : Token_sig.REPOSITORY) :
  Token_sig.SERVICE = struct
  let lifecycle =
    Core.Container.Lifecycle.make "token"
      (fun ctx ->
        (let* () = Repo.register_migration ctx in
         Repo.register_cleaner ctx)
        |> Lwt.map (fun () -> ctx))
      (fun _ -> Lwt.return ())

  let find_opt ctx ~value () =
    let* token = Repo.find_opt ctx ~value in
    Lwt.return
    @@ Option.bind token ~f:(fun tk ->
           if Token_core.is_valid tk then token else None)

  let find ctx ~value () =
    let* token = find_opt ctx ~value () in
    token
    |> Result.of_option
         ~error:
           (Printf.sprintf "Token with value %s not found or not valid" value)
    |> Result.ok_or_failwith |> Lwt.return

  let find_by_id_opt ctx ~id () =
    let* token = Repo.find_by_id_opt ctx ~id in
    Lwt.return
    @@ Option.bind token ~f:(fun tk ->
           if Token_core.is_valid tk then token else None)

  let find_by_id ctx ~id () =
    let* token = find_by_id_opt ctx ~id () in
    token
    |> Result.of_option
         ~error:(Printf.sprintf "Token with id %s not found or not valid" id)
    |> Result.ok_or_failwith |> Lwt.return

  let create ctx ~kind ?data ?expires_in () =
    let expires_in = Option.value ~default:Utils.Time.OneDay expires_in in
    let id = Data.Id.random () |> Data.Id.to_string in
    let token = Token_core.make ~id ~kind ~data ~expires_in () in
    let* result =
      Db.atomic ctx (fun ctx ->
          let* () = Repo.insert ctx ~token in
          let value = Token_core.value token in
          find ctx ~value ())
    in
    Lwt.return result

  let invalidate ctx ~token () =
    Repo.update ctx ~token:(Token_core.invalidate token)
end
