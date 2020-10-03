open Lwt.Syntax
open Alcotest_lwt

module Token =
  Test_common.Test.Token.Make (Service.Database) (Service.Repo) (Service.Token)

module Session =
  Test_common.Test.Session.Make (Service.Database) (Service.Repo) (Service.Session)

module Storage =
  Test_common.Test.Storage.Make (Service.Database) (Service.Repo) (Service.Storage)

module User = Test_common.Test.User.Make (Service.Database) (Service.Repo) (Service.User)

module Email =
  Test_common.Test.Email.Make (Service.Database) (Service.Repo) (Service.EmailTemplate)

module PasswordReset =
  Test_common.Test.PasswordReset.Make (Service.Database) (Service.Repo) (Service.User)
    (Service.PasswordReset)

module Queue = Test_common.Test.Queue.Make (Service.Repo) (Service.Queue)

let test_suite ctx =
  [ Token.test_suite
  ; Session.test_suite
  ; Storage.test_suite
  ; User.test_suite
  ; Email.test_suite
  ; PasswordReset.test_suite
  ; (* We need to add the DB Pool to the scheduler context *)
    Queue.test_suite ctx Service.Database.add_pool
  ]
;;

let services =
  [ Service.Database.configure
      [ "DATABASE_URL", "mariadb://admin:password@127.0.0.1:3306/dev" ]
  ; Service.Session.configure []
  ; Service.Token.configure []
  ; Service.User.configure []
  ; Service.Storage.configure []
  ; Service.EmailTemplate.configure []
  ; Service.PasswordReset.configure []
  ; Service.Queue.configure [] []
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
     run "mariadb" @@ test_suite ctx)
;;
