open Alcotest_lwt

let ( let* ) = Lwt.bind

let suite = [ Test_common.Test.session; Test_common.Test.storage ]

let () =
  Lwt_main.run
    (let* () =
       let ctx = Sihl.Test.context () in
       Sihl.Test.with_services ctx
         [
           Sihl.Data.Migration.Service.mariadb;
           Sihl.Storage.Service.mariadb;
           Sihl.Session.Service.mariadb;
         ]
     in
     run "mariadb tests" suite)
