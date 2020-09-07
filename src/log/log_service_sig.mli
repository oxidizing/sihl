module type SERVICE = sig
  include Core.Container.SERVICE

  type level = App | Error | Warning | Info | Debug

  val set_level : ?all:bool -> level option -> unit

  type src

  module Tag : sig
    type set
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
end
