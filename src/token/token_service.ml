open Base
module Repo = Token_service_repo

let ( let* ) = Lwt_result.bind

module Make (Db : Data_db_sig.SERVICE) (Repo : Token_sig.REPOSITORY) :
  Token_sig.SERVICE = struct
  let lifecycle =
    Core.Container.Lifecycle.make "token"
      (fun ctx ->
        (let* () = Repo.register_migration ctx in
         Repo.register_cleaner ctx)
        |> Lwt.map Result.ok_or_failwith
        |> Lwt.map (fun () -> ctx))
      (fun _ -> Lwt.return ())

  let find_opt ctx ~value () = Repo.find_opt ctx ~value

  let find ctx ~value () =
    let* token = find_opt ctx ~value () in
    token
    |> Result.of_option ~error:(Printf.sprintf "Token %s not found" value)
    |> Lwt.return

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
end
