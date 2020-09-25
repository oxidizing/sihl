(** A simple query language that can be used for HTTP queries that get passed into repositories. It currently supports filtering, sorting and pagination. *)

module Filter : sig
  type op = Eq | Like

  type criterion = { key : string; value : string; op : op }

  type t = And of t list | Or of t list | C of criterion
end

module Sort : sig
  type criterion = Asc of string | Desc of string

  type t = criterion list
end

module Page : sig
  type t = { limit : int option; offset : int option }

  val pp : Format.formatter -> t -> unit

  val show : t -> string

  val equal : t -> t -> bool

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val empty : t

  val set_limit : int -> t -> t

  val set_offset : int -> t -> t

  val get_limit : t -> int option

  val get_offset : t -> int option

  val of_string : string -> (t, string) Result.t

  val to_string : t -> string
end

type t = { filter : Filter.t option; sort : Sort.t option; page : Page.t }

val to_yojson : t -> Yojson.Safe.t

val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

val pp : Format.formatter -> t -> unit

val equal : t -> t -> bool

val of_string : string -> (t, string) Result.t

val to_sql : string list -> t -> string * string list

val to_sql_fragments :
  string list -> t -> string * string * string * string list

val to_string : t -> string

val empty : t

val set_filter : Filter.t -> t -> t

val set_filter_and : Filter.criterion -> t -> t

val set_sort : Sort.t -> t -> t

val set_limit : int -> t -> t

val set_offset : int -> t -> t

val get_page : t -> Page.t

val get_limit : t -> int option

val get_offset : t -> int option
