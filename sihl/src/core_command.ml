let log_src = Logs.Src.create "sihl.core.command"

module Logs = (val Logs.src_log log_src : Logs.LOG)

exception Exception of string

type t =
  { name : string
  ; usage : string option
  ; description : string
  ; dependencies : Core_lifecycle.lifecycle list [@opaque]
  ; fn : string list -> unit option Lwt.t [@opaque] [@equal fun _ _ -> true]
  }
[@@deriving eq, show]

let make ~name ?help ~description ?(dependencies = []) fn =
  { name; usage = help; description; dependencies; fn }
;;

let find_command_by_args commands args =
  let ( let* ) = Option.bind in
  try
    let* name = CCList.head_opt args in
    List.find_opt (fun command -> String.equal command.name name) commands
  with
  | _ -> None
;;

let print_all commands =
  let version =
    match Build_info.V1.version () with
    | None -> ""
    | Some version -> Build_info.V1.Version.to_string version
  in
  let command_list =
    commands
    |> List.map (fun command -> command.name)
    |> List.sort String.compare
    |> String.concat "\n"
  in
  print_endline
  @@ Printf.sprintf
       {|
Sihl %s

Run one of the following commands with the argument "help" for more information.

%s
|}
       version
       command_list
;;

let print_help (command : t) =
  let usage = Option.map (Printf.sprintf "%s %s" command.name) command.usage in
  print_endline
  @@
  match usage with
  | None -> String.concat "\n" [ command.name; command.description ]
  | Some usage -> String.concat "\n" [ usage; command.description ]
;;

let run commands args =
  let args =
    match args with
    | Some args -> args
    | None ->
      (try Sys.argv |> Array.to_list |> List.tl with
       | _ -> [])
  in
  let command = find_command_by_args commands args in
  match command with
  | Some command ->
    (* We use the first argument to find the command, the command itself
       receives the rest arguments. *)
    let rest_args =
      try args |> List.tl with
      | _ -> []
    in
    (match rest_args with
     | [ "help" ] -> Lwt.return @@ print_help command
     | rest_args ->
       let start = Mtime_clock.now () in
       Lwt.catch
         (fun () ->
            let%lwt _ =
              Lwt_list.iter_s (fun (lifecycle : Core_lifecycle.lifecycle) ->
                lifecycle.start ())
              @@ Core_lifecycle.top_sort_lifecycles command.dependencies
            in
            let%lwt result = command.fn rest_args in
            match result with
            | Some () ->
              let stop = Mtime_clock.now () in
              let span = Mtime.span start stop in
              print_endline
                (Format.asprintf
                   "Command '%s' ran successfully in %a"
                   command.name
                   Mtime.Span.pp
                   span);
              Lwt.return ()
            | None -> Lwt.return @@ print_help command)
         (fun exn ->
            let stop = Mtime_clock.now () in
            let span = Mtime.span start stop in
            let msg = Printexc.to_string exn in
            let stack = Printexc.get_backtrace () in
            print_endline
              (Format.asprintf
                 "Command '%s' aborted after %a: '%s'"
                 command.name
                 Mtime.Span.pp
                 span
                 msg);
            print_endline stack;
            exit 1))
  | None ->
    print_all commands;
    Lwt.return ()
;;
