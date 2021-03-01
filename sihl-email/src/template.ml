include Sihl.Contract.Email_template

let log_src =
  Logs.Src.create ("sihl.service." ^ Sihl.Contract.Email_template.name)
;;

module Logs = (val Logs.src_log log_src : Logs.LOG)

module Make (Repo : Template_repo_sql.Sig) : Sihl.Contract.Email_template.Sig =
struct
  let get id = Repo.get id
  let get_by_label label = Repo.get_by_label label

  let create ?html ~label text =
    let open Lwt.Syntax in
    let open Sihl.Contract.Email_template in
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
            Sihl.Contract.Email_template.pp
            template);
      raise (Sihl.Contract.Email.Exception "Could not create email template")
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
            Sihl.Contract.Email_template.pp
            template);
      raise (Sihl.Contract.Email.Exception "Could not create email template")
    | Some created -> Lwt.return created
  ;;

  let start () = Lwt.return ()
  let stop () = Lwt.return ()

  let lifecycle =
    Sihl.Container.create_lifecycle
      Sihl.Contract.Email_template.name
      ~dependencies:(fun () -> Repo.lifecycles)
      ~start
      ~stop
  ;;

  let register () =
    Repo.register_migration ();
    Repo.register_cleaner ();
    Sihl.Container.Service.create lifecycle
  ;;
end

module PostgreSql =
  Make (Template_repo_sql.MakePostgreSql (Sihl.Database.Migration.PostgreSql))

module MariaDb =
  Make (Template_repo_sql.MakeMariaDb (Sihl.Database.Migration.MariaDb))
