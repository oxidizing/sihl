module M = Minicli.CLI

let forward_command bin_app_path args =
  let command = Format.sprintf "%s %s" bin_app_path (String.concat " " args) in
  print_endline @@ Format.sprintf "forwarding command %s" command;
  let _ = Unix.system command in
  ()
;;

let run_init args =
  match Hashtbl.find_opt Sihl.Command.commands "init" with
  | None -> failwith "could not find command init"
  | Some command ->
    let help = M.get_set_bool [ "--help" ] args in
    M.finalize ();
    if help
    then (
      print_endline command.description;
      print_endline @@ Format.sprintf "  %s" command.usage)
    else (
      try command.fn args with
      | Sihl.Command.Invalid_usage -> print_endline command.usage)
;;

let () =
  Printexc.record_backtrace true;
  let _, args = M.init () in
  let bin_dune = Sihl.Config.bin_dune () in
  let bin_app_path = Sihl.Config.bin_app_path () in
  print_endline @@ Format.sprintf "args: %s" (String.concat " " args);
  match args with
  | _ :: "init" :: args ->
    (* We know that the init command is available *)
    run_init args
  | _ :: name :: args ->
    (* Everything else we forward to the app binary by default, after
       building *)
    print_endline "compile app";
    let s_build = Unix.system (bin_dune ^ " build") in
    (match s_build with
    | Unix.WEXITED 0 ->
      if CCIO.File.exists bin_app_path
      then (
        match Hashtbl.find_opt Sihl.Command.commands name with
        | None -> forward_command bin_app_path (List.cons name args)
        | Some command ->
          (* Stateful commands we have to forward, they depend on the state Sihl
             builds up *)
          if command.stateful
          then forward_command bin_app_path (List.cons name args)
          else Sihl.Command.run ())
      else (
        print_endline
        @@ Format.sprintf
             "App not found at %s, did you change the binary name from bin.ml?\n\
             \  sihl init --help"
             bin_app_path;
        failwith "could not run app")
    | _ ->
      print_endline
        "It seems like this is not a Sihl project, initialize one\n\
        \  sihl init --help";
      failwith "could not run app")
  | [ _ ] | [] ->
    if CCIO.File.exists bin_app_path
    then forward_command bin_app_path []
    else Sihl.Command.print_help ()
;;
