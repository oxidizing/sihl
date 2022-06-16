type t =
  { name : string
  ; description : string
  ; usage : string
  ; fn : string list -> unit
  }

exception Invalid_usage
