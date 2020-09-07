(** Use the configuration service to read configuration from various sources like environment variables, .env files or some key-value store. Configurations are typically required by services. An example would be a email service that needs SMTP credentials.
 *)

module type SERVICE = sig
  include Core.Container.SERVICE

  val register_config : Config_core.t -> unit

  val is_testing : unit -> bool

  val is_production : unit -> bool

  val read_string_default : default:string -> string -> string

  val read_string_opt : string -> string option

  val read_string : ?default:string -> string -> string

  val read_int_opt : string -> int option

  val read_int : ?default:int -> string -> int

  val read_bool_opt : string -> bool option

  val read_bool : ?default:bool -> string -> bool
end
