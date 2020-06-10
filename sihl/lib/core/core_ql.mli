module Filter : sig
  type op = Eq | Like

  type criterion = { key : string; value : string; op : op }

  type t = And of t list | Or of t list | C of criterion
end

module Sort : sig
  type criterion = Asc of string | Desc of string

  type t = criterion list
end

type t = {
  filter : Filter.t option;
  sort : Sort.t option;
  limit : int option;
  offset : int option;
}

val pp : Format.formatter -> t -> unit

val equal : t -> t -> bool

val of_string : string -> (t, string) Result.t

val to_sql : t -> string

val to_string : t -> string

val empty : t

val filter : Filter.t -> t -> t

val sort : Sort.t -> t -> t

val limit : int -> t -> t

val offset : int -> t -> t
