type command =
  { name : string
  ; description : string
  ; usage : string
  ; fn : string list -> unit Lwt.t
  }

and group =
  { name_group : string
  ; description_group : string
  ; commands : t list
  }

and t =
  | Command of command
  | Group of group
