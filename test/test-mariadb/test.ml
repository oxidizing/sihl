open Alcotest_lwt

let ( let* ) = Lwt.bind

let suite = [ Test_common.Test.session; Test_common.Test.storage ]

let config =
  Sihl.Config.create ~development:[]
    ~test:[ ("DATABASE_URL", "mariadb://root:password@127.0.0.1:3306/dev") ]
    ~production:[]

let () =
  Lwt_main.run
    (let* () =
       let ctx = Sihl.Core.Ctx.empty |> Sihl.Data.Db.add_pool in
       let* () =
         Sihl.Config.register_config ctx config
         |> Lwt.map Base.Result.ok_or_failwith
       in
       Sihl.Test.with_services ctx
         [
           Sihl.Data.Migration.Service.mariadb;
           Sihl.Storage.Service.mariadb;
           Sihl.Session.Service.mariadb;
         ]
     in
     run "mariadb tests" @@ suite)
