module Model = Migration_service.Model

module Service : sig
  module type SERVICE = Migration_sig.SERVICE

  module type REPO = Migration_sig.REPO

  module Make : functor (Repo : REPO) -> SERVICE

  module PostgreSql : SERVICE

  val postgresql : Core.Container.binding

  val mariadb : Core.Container.binding

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

val execute : t list -> (unit, string) Result.t Lwt.t

val register : Opium_kernel.Request.t -> t -> (unit, string) Lwt_result.t

val get_migrations : Opium_kernel.Request.t -> (t list, string) Lwt_result.t
