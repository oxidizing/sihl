module Setting : sig
  type key_value = string * string

  type t

  val create :
    development:key_value list ->
    test:key_value list ->
    production:key_value list ->
    t
end

module Schema : sig
  module Type : sig
    type 'a condition = Default of 'a | RequiredIf of string * string | None

    type choices = string list

    type t

    val key : t -> string

    val validate : t -> (string, string, 'a) Base.Map.t -> (unit, string) result
  end

  type t = Type.t list

  val keys : Type.t list -> string list

  val condition : (string * string) option -> 'a option -> 'a Type.condition

  val string_ :
    ?required_if:string * string ->
    ?default:string ->
    ?choices:Type.choices ->
    string ->
    Type.t

  val int_ : ?required_if:string * string -> ?default:int -> string -> Type.t

  val bool_ : ?required_if:string * string -> ?default:bool -> string -> Type.t
end

val of_list :
  (string * 'a) list ->
  ((string, 'a, Base.String.comparator_witness) Base.Map.t, string) result

val is_testing : unit -> bool

val process :
  Schema.Type.t list list ->
  Setting.t ->
  ((string, string, Base.String.comparator_witness) Base.Map.t, string) result

val load_config : Schema.Type.t list list -> Setting.t -> unit

val read_string : ?default:string -> string -> string

val read_int : ?default:int -> string -> int

val read_bool : ?default:bool -> string -> bool
