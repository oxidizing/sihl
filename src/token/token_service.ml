open Base
module Repo = Token_service_repo

let ( let* ) = Lwt_result.bind

module Make
    (Db : Data_db_sig.SERVICE)
    (RepoService : Data.Repo.Sig.SERVICE)
    (MigrationService : Data.Migration.Sig.SERVICE)
    (TokenRepo : Token_sig.REPOSITORY) : Token_sig.SERVICE = struct
  let on_init ctx =
    let* () = MigrationService.register ctx (TokenRepo.migrate ()) in
    RepoService.register_cleaner ctx TokenRepo.clean

  let on_start _ = Lwt.return @@ Ok ()

  let on_stop _ = Lwt.return @@ Ok ()

  let find_opt ctx ~value () = TokenRepo.find_opt ~value |> Db.query ctx

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
          let* () = TokenRepo.insert ~token |> Db.query ctx in
          let value = Token_core.value token in
          find ctx ~value ())
    in
    Lwt.return result
end
