open Base

type fn = string list -> unit Lwt.t [@@deriving show]

exception Invalid_usage of string

type t = { name : string; help : string option; description : string; fn : fn }
[@@deriving show, fields, make]

let show command =
  match command.help with
  | Some help ->
      Printf.sprintf "%s %s: %s" command.name help command.description
  | None -> Printf.sprintf "%s: %s" command.name command.description
