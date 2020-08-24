module type SERVICE = sig
  include Core_container.SERVICE

  val register_config : 'a -> Config_core.Config.t -> unit Lwt.t

  val is_testing : unit -> bool

  val is_production : unit -> bool

  val read_string_default : default:string -> string -> string

  val read_string : ?default:string -> string -> string

  val read_int : ?default:int -> string -> int

  val read_bool : ?default:bool -> string -> bool
end
