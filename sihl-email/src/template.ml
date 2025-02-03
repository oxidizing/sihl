include Sihl.Contract.Email_template

let log_src =
  Logs.Src.create ("sihl.service." ^ Sihl.Contract.Email_template.name)
;;

module Logs = (val Logs.src_log log_src : Logs.LOG)

module Make (Repo : Template_repo_sql.Sig) : Sihl.Contract.Email_template.Sig =
struct
  let get = Repo.get
  let get_by_label = Repo.get_by_label

  let create ?ctx ?id ?html ?language ~label text =
    let open Sihl.Contract.Email_template in
    let now = Ptime_clock.now () in
    let id = Option.value id ~default:(Sihl.Random.Uuid.create ()) in
    let template =
      { id; label; language; html; text; created_at = now; updated_at = now }
    in
    let%lwt () = Repo.insert ?ctx template in
    let%lwt created = Repo.get ?ctx id in
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

  let update ?ctx template =
    let%lwt () = Repo.update ?ctx template in
    let id = template.id in
    let%lwt created = Repo.get ?ctx id in
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
