open Base

let registered_commands : Cmd_core.t list ref = ref []

let lifecycle =
  Core.Container.Lifecycle.make "cmd"
    (fun ctx -> Lwt.return ctx)
    (fun _ -> Lwt.return ())

let register_commands commands =
  registered_commands := List.concat [ !registered_commands; commands ]

let register_command command =
  registered_commands := List.cons command !registered_commands

let find_command_by_args commands args =
  args |> List.hd
  |> Option.bind ~f:(fun name ->
         commands
         |> List.find ~f:(fun command ->
                String.equal (Cmd_core.name command) name))

let print_all commands =
  let command_list =
    commands |> List.map ~f:Cmd_core.show |> String.concat ~sep:"\n"
  in
  Caml.print_endline
  @@ Printf.sprintf
       {|
  ______    _   __       __
.' ____ \  (_) [  |     [  |
| (___ \_| __   | |--.   | |
 _.____`. [  |  | .-. |  | |
| \____) | | |  | | | |  | |
 \______.'[___][___]|__][___]

--------------------------------------------
%s
--------------------------------------------
|}
       command_list

let run () =
  let args =
    Sys.get_argv () |> Array.to_list |> List.tl |> Option.value ~default:[]
  in
  let commands = !registered_commands in
  let command = find_command_by_args commands args in
  match command with
  | Some command ->
      (* We use the first argument to find the command, the command it self receives all the rest *)
      let rest_args = args |> List.tl |> Option.value ~default:[] in
      (* TODO catch all exceptions here *)
      Cmd_core.fn command rest_args
  | None ->
      print_all commands;
      Lwt.return ()
