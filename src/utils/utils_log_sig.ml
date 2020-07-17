module type SERVICE = sig
  type level = App | Error | Warning | Info | Debug

  val level : unit -> level option

  val set_level : ?all:bool -> level option -> unit

  val pp_level : Format.formatter -> level -> unit

  val level_to_string : level option -> string

  val level_of_string : string -> (level option, [ `Msg of string ]) result

  type src

  val default : src

  module Src : sig
    type t = src

    val create : ?doc:string -> string -> t

    val name : t -> string

    val doc : t -> string

    val level : t -> level option

    val set_level : t -> level option -> unit

    val equal : t -> t -> bool

    val compare : t -> t -> int

    val pp : Format.formatter -> t -> unit

    val list : unit -> t list
  end

  module Tag : sig
    type 'a def

    type def_e = Def : 'a def -> def_e

    val def :
      ?doc:string -> string -> (Format.formatter -> 'a -> unit) -> 'a def

    val name : 'a def -> string

    val doc : 'a def -> string

    val printer : 'a def -> Format.formatter -> 'a -> unit

    val pp_def : Format.formatter -> 'a def -> unit

    val list : unit -> def_e list

    type t = V : 'a def * 'a -> t

    val pp : Format.formatter -> t -> unit

    type set

    val empty : set

    val is_empty : set -> bool

    val mem : 'a def -> set -> bool

    val add : 'a def -> 'a -> set -> set

    val rem : 'a def -> set -> set

    val find : 'a def -> set -> 'a option

    val get : 'a def -> set -> 'a

    val fold : (t -> 'a -> 'a) -> set -> 'a -> 'a

    val pp_set : Format.formatter -> set -> unit
  end

  type ('a, 'b) msgf =
    (?header:string ->
    ?tags:Tag.set ->
    ('a, Format.formatter, unit, 'b) format4 ->
    'a) ->
    'b

  type 'a log = ('a, unit) msgf -> unit

  val msg : ?src:src -> level -> 'a log

  val app : ?src:src -> 'a log

  val err : ?src:src -> 'a log

  val warn : ?src:src -> 'a log

  val info : ?src:src -> 'a log

  val debug : ?src:src -> 'a log

  val kmsg : (unit -> 'b) -> ?src:src -> level -> ('a, 'b) msgf -> 'b

  val on_error :
    ?src:src ->
    ?level:level ->
    ?header:string ->
    ?tags:Tag.set ->
    pp:(Format.formatter -> 'b -> unit) ->
    use:('b -> 'a) ->
    ('a, 'b) result ->
    'a

  val on_error_msg :
    ?src:src ->
    ?level:level ->
    ?header:string ->
    ?tags:Tag.set ->
    use:(unit -> 'a) ->
    ('a, [ `Msg of string ]) result ->
    'a

  module type LOG = sig
    val msg : level -> 'a log

    val app : 'a log

    val err : 'a log

    val warn : 'a log

    val info : 'a log

    val debug : 'a log

    val kmsg : (unit -> 'b) -> level -> ('a, 'b) msgf -> 'b

    val on_error :
      ?level:level ->
      ?header:string ->
      ?tags:Tag.set ->
      pp:(Format.formatter -> 'b -> unit) ->
      use:('b -> 'a) ->
      ('a, 'b) result ->
      'a

    val on_error_msg :
      ?level:level ->
      ?header:string ->
      ?tags:Tag.set ->
      use:(unit -> 'a) ->
      ('a, [ `Msg of string ]) result ->
      'a
  end

  val src_log : src -> (module LOG)

  type reporter = {
    report :
      'a 'b. src -> level -> over:(unit -> unit) -> (unit -> 'b) ->
      ('a, 'b) msgf -> 'b;
  }

  val nop_reporter : reporter

  val format_reporter :
    ?pp_header:(Format.formatter -> level * string option -> unit) ->
    ?app:Format.formatter ->
    ?dst:Format.formatter ->
    unit ->
    reporter

  val reporter : unit -> reporter

  val set_reporter : reporter -> unit

  val set_reporter_mutex : lock:(unit -> unit) -> unlock:(unit -> unit) -> unit

  val report :
    src -> level -> over:(unit -> unit) -> (unit -> 'b) -> ('a, 'b) msgf -> 'b

  val incr_err_count : unit -> unit

  val incr_warn_count : unit -> unit

  val pp_print_text : Format.formatter -> string -> unit

  val pp_header : Format.formatter -> level * string option -> unit

  val err_count : unit -> int

  val warn_count : unit -> int
end
