module Model = Data_migration_core
module Sig = Data_migration_sig
module Service = Data_migration_service

type step = Model.Migration.step

type t = Model.Migration.t

val pp : Format.formatter -> t -> unit

val show : t -> string

val equal : t -> t -> bool

val empty : string -> t

val create_step : label:string -> ?check_fk:bool -> string -> step

val add_step : step -> t -> t
