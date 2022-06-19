module M = Minicli.CLI
include Command_pure

let commands : (string, t) Hashtbl.t = Hashtbl.create 20
let register (cmd : t) = Hashtbl.add commands cmd.name cmd

let version () =
  match Build_info.V1.version () with
  | None -> "%%VERSION%%"
  | Some version -> Build_info.V1.Version.to_string version
;;

let command_names () =
  commands
  |> Hashtbl.to_seq_keys
  |> List.of_seq
  |> List.sort String.compare
  |> String.concat "\n   "
;;

let print_help () =
  Printf.printf
    "Sihl %s\nRun one of the following commands with the argument --help\n   %s"
    (version ())
    (command_names ())
;;

let run () =
  let module M = Minicli.CLI in
  let argc, args = M.init () in
  if argc = 1
  then (
    print_help ();
    exit 1)
  else (
    match args with
    | _ :: command :: args ->
      (match Hashtbl.find_opt commands command with
      | None -> failwith @@ Format.sprintf "command %s unknown" command
      | Some command ->
        let help = M.get_set_bool [ "--help" ] args in
        if help
        then (
          print_endline command.description;
          print_endline @@ Format.sprintf "  %s" command.usage)
        else (
          try command.fn args with
          | Invalid_usage -> print_endline command.usage))
    | _ -> ())
;;

let () =
  register Command_init.t;
  register Command_dev.t;
  register Command_shell.t;
  register Command_test.t;
  register Command_test.cov;
  register Command_migrate.t;
  register Command_migrate.gen;
  register Command_migrate.down
;;
