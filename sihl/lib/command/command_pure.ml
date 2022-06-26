type t =
  { name : string
  ; description : string
  ; usage : string
  ; fn : string list -> unit
  ; stateful : bool
  }

exception Invalid_usage
