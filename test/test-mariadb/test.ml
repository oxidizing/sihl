open Alcotest_lwt

let ( let* ) = Lwt.bind

let suite =
  [ Test_common.Test.session; Test_common.Test.storage; Test_common.Test.user ]

let config =
  Sihl.Config.create ~development:[]
    ~test:[ ("DATABASE_URL", "mariadb://admin:password@127.0.0.1:3306/dev") ]
    ~production:[]

let services =
  [
    Sihl.Data.Migration.Service.mariadb;
    Sihl.Storage.Service.mariadb;
    Sihl.Session.Service.mariadb;
    Sihl.User.Service.mariadb;
  ]

let () =
  Lwt_main.run
    (let* () =
       let ctx = Sihl.Core.Ctx.empty in
       Sihl.Test.app ctx ~config ~services
     in
     run "mariadb" @@ suite)
