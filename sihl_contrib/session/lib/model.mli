module Session : sig
  type data_map = (string * string) list

  type data = (string, string, Base.String.comparator_witness) Base.Map.t

  type t = { key : string; data : data; expire_date : Ptime.t }

  val create : Ptime.t -> t

  val key : t -> string

  val data : t -> (string, string, Base.String.comparator_witness) Base.Map.t

  val data_of_string : string -> (data, string) Result.t

  val string_of_data : data -> string

  val get : string -> t -> string option

  val set : key:string -> value:string -> t -> t

  val pp : Format.formatter -> t -> unit
end
