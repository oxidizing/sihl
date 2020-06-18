type step = { label : string; statement : string; check_fk : bool }

type t = string * step list
