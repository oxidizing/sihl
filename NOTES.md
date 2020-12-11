# New API

```ocaml
let schedules = [ Schedule.Export.delete_old_exports ]

let jobs =
  [ Job.Export.export_applications_excel; Job.Export.export_applications_pdf ]

let routers = Route.all

let migrations =
  [ Database.Migration.questionnaire; Database.Migration.application ]

let services =
  [
    Sihl.Service.Token.register ();
    Sihl.Service.User.register ();
    Sihl.Service.Session.register ();
    Sihl.Service.Email.register
       ~implementation:(module Sihl.Service.Email.Smtp) ();
    Sihl.Service.Email_template.register ();
    Sihl.Service.Schedule.register ~schedules ();
    Sihl.Service.Queue.register ~jobs ();
    Sihl.Service.Http.register ~routers ();
  ]

let commands =
  [
    Command.Export.export_applications;
    Command.Export.delete_exports;
    Command.Seed.dev_data;
  ]

let set_database_url () =
  let () =
    match
      (Sys.getenv_opt "DEVCONTAINER_DATABASE_URL", Sys.getenv_opt "DATABASE_URL")
    with
    | Some database_url, _ -> Unix.putenv "DATABASE_URL" database_url
    | None, Some database_url -> Unix.putenv "DATABASE_URL" database_url
    | None, None ->
        Unix.putenv "DATABASE_URL" "mariadb://root:password@127.0.0.1:3306/dev"
  in
  Lwt.return ()

let () =
  Sihl.App.(
    empty
    |> before_start set_database_url
    |> with_services services
    |> before_start (fun () ->
           Printexc.record_backtrace true;
           set_database_url ())
    |> run ~commands)
```
