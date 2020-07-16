module PartialCollection : sig
  type view

  val last : view -> Data_ql.t option

  val next : view -> Data_ql.t option

  val previous : view -> Data_ql.t option

  val first : view -> Data_ql.t option

  val pp_view : Format.formatter -> view -> unit

  val show_view : view -> string

  val equal_view : view -> view -> bool

  val view_to_yojson : view -> Yojson.Safe.t

  val view_of_yojson :
    Yojson.Safe.t -> view Ppx_deriving_yojson_runtime.error_or

  type 'a t = { id : string; member : 'a list; total_items : int; view : view }

  val create :
    string -> query:Data_ql.t -> meta:Data_repo.Meta.t -> 'a list -> 'a t

  val view : 'a t -> view

  val total_items : 'a t -> int

  val member : 'a t -> 'a list

  val id : 'a t -> string

  val pp : (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a t -> unit

  val show : (Format.formatter -> 'a -> unit) -> 'a t -> string

  val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

  val to_yojson : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t

  val of_yojson :
    (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or) ->
    Yojson.Safe.t ->
    'a t Ppx_deriving_yojson_runtime.error_or
end
