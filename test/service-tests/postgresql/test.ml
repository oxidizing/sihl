open Lwt.Syntax

module Session =
  Test_case.Session.Make (Service.Database) (Service.Repository) (Service.Session)

module User = Test_case.User.Make (Service.Database) (Service.Repository) (Service.User)

module Email =
  Test_case.Email.Make (Service.Database) (Service.Repository) (Service.EmailTemplate)

let test_suite _ = [ Session.test_suite; User.test_suite; Email.test_suite ]

let services =
  [ Service.Database.configure
      [ "DATABASE_URL", "postgres://admin:password@127.0.0.1:5432/dev" ]
  ; Service.Session.configure []
  ; Service.User.configure []
  ; Service.EmailTemplate.configure []
  ]
;;

let () =
  Logs.set_reporter (Sihl.Core.Log.default_reporter ());
  let ctx = Sihl.Core.Ctx.empty in
  let configurations =
    List.map (fun service -> Sihl.Core.Container.Service.configuration service) services
  in
  List.iter
    (fun configuration ->
      configuration |> Sihl.Core.Configuration.data |> Sihl.Core.Configuration.store)
    configurations;
  Lwt_main.run
    (let ctx = Service.Database.add_pool ctx in
     let* _ = Sihl.Core.Container.start_services services in
     let* () = Service.Migration.run_all ctx in
     Alcotest_lwt.run "postgresql" @@ test_suite ctx)
;;
