let log_src =
  Logs.Src.create ("sihl.service." ^ Sihl_contract.Email_template.name)
;;

module Logs = (val Logs.src_log log_src : Logs.LOG)

module Make (Repo : Sihl_email_template_repo.Sig) :
  Sihl_contract.Email_template.Sig = struct
  let get id = Repo.get id
  let get_by_label label = Repo.get_by_label label

  let create ?html ~label text =
    let open Lwt.Syntax in
    let open Sihl_contract.Email_template in
    let now = Ptime_clock.now () in
    let id = Uuidm.create `V4 |> Uuidm.to_string in
    let template =
      { id; label; html; text; created_at = now; updated_at = now }
    in
    let* () = Repo.insert template in
    let* created = Repo.get id in
    match created with
    | None ->
      Logs.err (fun m ->
          m
            "Could not create template %a"
            Sihl_facade.Email_template.pp
            template);
      raise (Sihl_contract.Email.Exception "Could not create email template")
    | Some created -> Lwt.return created
  ;;

  let update template =
    let open Lwt.Syntax in
    let* () = Repo.update template in
    let id = template.id in
    let* created = Repo.get id in
    match created with
    | None ->
      Logs.err (fun m ->
          m
            "Could not update template %a"
            Sihl_facade.Email_template.pp
            template);
      raise (Sihl_contract.Email.Exception "Could not create email template")
    | Some created -> Lwt.return created
  ;;

  let start () = Lwt.return ()
  let stop () = Lwt.return ()

  let lifecycle =
    Sihl_core.Container.Lifecycle.create
      Sihl_contract.Email_template.name
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

module PostgreSql =
  Make
    (Sihl_email_template_repo.MakePostgreSql
       (Sihl_persistence.Migration.PostgreSql))

module MariaDb =
  Make (Sihl_email_template_repo.MakeMariaDb (Sihl_persistence.Migration.MariaDb))
