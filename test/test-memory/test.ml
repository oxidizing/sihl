open Alcotest_lwt

let ( let* ) = Lwt.bind

let suite =
  [ (* TODO once we have in-memory implementations we can test our services fast here *) ]

let services = []

let () = Lwt_main.run @@ run "memory" @@ suite
