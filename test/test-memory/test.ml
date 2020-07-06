open Alcotest_lwt

let ( let* ) = Lwt.bind

let suite =
  [ (* TODO once we have in-memory implementations we can test our services fast here *) ]

let config = Sihl.Config.create ~development:[] ~test:[] ~production:[]

let services = [ Sihl.Storage.Service.mariadb; Sihl.Session.Service.mariadb ]

let () =
  Lwt_main.run
    (let* () =
       let ctx = Sihl.Core.Ctx.empty in
       Sihl.Test.app ctx ~config ~services
     in
     run "memory" @@ suite)
