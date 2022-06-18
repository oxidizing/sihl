module P = Command_pure

let fn _ =
  let module M = Minicli.CLI in
  M.finalize ();
  (* Use janestreet's spawn for restarting process easily *)
  (* Unix.create_process "dune" [| "buil" |]; *)
  print_endline "start sihl";
  ()
;;

let t : P.t =
  { name = "dev"
  ; description = "Start a development web server with hot-reload"
  ; usage = "sihl dev"
  ; fn
  }
;;
