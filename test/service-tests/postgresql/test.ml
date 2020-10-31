open Lwt.Syntax
module Database = Test_case.Database
module Session = Test_case.Session.Make (Service.Session)
module User = Test_case.User.Make (Service.User)
module Email = Test_case.Email.Make (Service.EmailTemplate)

let test_suite =
  [ Database.test_suite; Session.test_suite; User.test_suite; Email.test_suite ]
;;

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
  let ctx = Sihl.Core.Ctx.create () in
  let configurations =
    List.map (fun service -> Sihl.Core.Container.Service.configuration service) services
  in
  List.iter
    (fun configuration ->
      configuration |> Sihl.Core.Configuration.data |> Sihl.Core.Configuration.store)
    configurations;
  Lwt_main.run
    (let* _ = Sihl.Core.Container.start_services services in
     let* () = Service.Migration.run_all ctx in
     Alcotest_lwt.run "postgresql" @@ test_suite)
;;
