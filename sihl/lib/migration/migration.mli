module Model = Migration_service.Model

module Service : sig
  module type SERVICE = Migration_sig.SERVICE

  module type REPO = Migration_sig.REPO

  module Make : functor (Repo : REPO) -> SERVICE

  module PostgreSql : SERVICE

  val postgresql : Core.Container.Binding.t

  val mariadb : Core.Container.Binding.t

  module MariaDb : SERVICE
end

type step = Model.Migration.step

type t = Model.Migration.t

val pp : Format.formatter -> t -> unit

val show : t -> string

val equal : t -> t -> bool

val empty : string -> t

val create_step : label:string -> ?check_fk:bool -> string -> step

val add_step : step -> t -> t

val execute_migration : t -> Core.Db.connection -> (unit, string) Result.t Lwt.t

val execute : t list -> (unit, string) Result.t Lwt.t
