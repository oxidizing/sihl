open Base

let ( let* ) = Lwt.bind

type fn = string list -> (unit, string) Result.t Lwt.t [@@deriving show]

type t = { name : string; help : string option; description : string; fn : fn }
[@@deriving show, fields, make]

let show command =
  match command.help with
  | Some help ->
      Printf.sprintf "%s %s: %s" command.name help command.description
  | None -> Printf.sprintf "%s: %s" command.name command.description
