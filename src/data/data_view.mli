module PartialCollection : sig
  type page

  val limit : page -> int

  val offset : page -> int

  val pp_page : Format.formatter -> page -> unit

  val show_page : page -> string

  val equal_page : page -> page -> bool

  type view

  val last : view -> page option

  val next : view -> page option

  val previous : view -> page option

  val first : view -> page option

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
