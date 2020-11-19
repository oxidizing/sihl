type step =
  { label : string
  ; statement : string
  ; check_fk : bool
  }
[@@deriving show, eq]

type t = string * step list [@@deriving show, eq]
