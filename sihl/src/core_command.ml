let log_src = Logs.Src.create "service.core.command"

module Logs = (val Logs.src_log log_src : Logs.LOG)

type fn = string list -> unit Lwt.t

exception Exception of string

type t =
  { name : string
  ; help : string option
  ; description : string
  ; fn : fn
  }

let make ~name ?help ~description fn = { name; help; description; fn }

let sexp_of_t { name; help; description; _ } =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  List
    [ List [ Atom "name"; sexp_of_string name ]
    ; List [ Atom "help"; sexp_of_option sexp_of_string help ]
    ; List [ Atom "description"; sexp_of_string description ]
    ]
;;

let show { name; help; description; _ } =
  let help = Option.value ~default:"-" help in
  let n_left_pad_help = 15 - String.length (CCString.take 15 name) in
  let n_left_pad_desc = 30 - String.length (CCString.take 30 help) in
  let padding_help = String.make n_left_pad_help ' ' in
  let padding_desc = String.make n_left_pad_desc ' ' in
  Format.sprintf " %s%s %s%s %s" name padding_help help padding_desc description
;;

let pp fmt t = Sexplib0.Sexp.pp_hum fmt (sexp_of_t t)

let find_command_by_args commands args =
  try
    let name = List.hd args in
    List.find_opt (fun command -> String.equal command.name name) commands
  with
  | _ -> None
;;

let print_all commands =
  let command_list = commands |> List.map show |> String.concat "\n" in
  Caml.print_endline
  @@ Printf.sprintf
       {|
  ______    _   __       __
.' ____ \  (_) [  |     [  |
| (___ \_| __   | |--.   | |
 _.____`. [  |  | .-. |  | |
| \____) | | |  | | | |  | |
 \______.'[___][___]|__][___]

 Run one of the following commands like "make sihl <command name>".
-------------------------------------------------------------------
 Command Name   | Usage                        | Description
-------------------------------------------------------------------
%s
-------------------------------------------------------------------
|}
       command_list
;;

let run commands args =
  let open Lwt.Syntax in
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
    (* We use the first argument to find the command, the command it self
       receives all the rest *)
    let rest_args =
      try args |> List.tl with
      | _ -> []
    in
    let start = Mtime_clock.now () in
    Lwt.catch
      (fun () ->
        let* () = command.fn rest_args in
        let stop = Mtime_clock.now () in
        let span = Mtime.span start stop in
        print_endline
          (Format.asprintf
             "Command '%s' ran successfully in %a"
             command.name
             Mtime.Span.pp
             span);
        Lwt.return ())
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
        Lwt.return ())
  | None ->
    print_all commands;
    Lwt.return ()
;;
