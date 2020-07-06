open Alcotest_lwt

let ( let* ) = Lwt.bind

let suite =
  [ (* TODO once we have in-memory implementations we can test our services fast here *) ]

let services =
  [
    Sihl.Utils.Random.Service.instance;
    Sihl.Log.Service.instance;
    Sihl.Config.Service.instance;
  ]

let () =
  Lwt_main.run
    (let* () =
       let ctx = Sihl.Core.Ctx.empty in
       Sihl.Test.services ctx services ~before_start:(fun () -> Lwt.return ())
     in
     run "memory" @@ suite)
