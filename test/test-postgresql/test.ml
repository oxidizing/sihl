open Alcotest_lwt

let ( let* ) = Lwt.bind

let suite = [ Test_common.Test.session; Test_common.Test.user ]

let config =
  Sihl.Config.create ~development:[]
    ~test:[ ("DATABASE_URL", "postgres://admin:password@127.0.0.1:5432/dev") ]
    ~production:[]

let services =
  [
    Sihl.Data.Migration.Service.postgresql;
    Sihl.Session.Service.postgresql;
    Sihl.User.Service.postgresql;
  ]

let () =
  Lwt_main.run
    (let* () =
       let ctx = Sihl.Core.Ctx.empty in
       Sihl.Test.app ctx ~config ~services
     in
     run "postgresql" @@ suite)
