open Alcotest_lwt

let ( let* ) = Lwt.bind

let suite = [ Test_common.Test.session; Test_common.Test.storage ]

let config =
  Sihl.Config.create ~development:[]
    ~test:[ ("DATABASE_URL", "mariadb://admin:password@127.0.0.1:3306/dev") ]
    ~production:[]

let services =
  [
    Sihl.Data.Migration.Service.mariadb;
    Sihl.Storage.Service.mariadb;
    Sihl.Session.Service.mariadb;
  ]

let () =
  Lwt_main.run
    (let* () =
       let ctx = Sihl.Core.Ctx.empty in
       Sihl.Test.app ctx ~config ~services
     in
     run "mariadb" @@ suite)
