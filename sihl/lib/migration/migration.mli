module Model = Migration_service.Model

module type SERVICE = Migration_service.SERVICE

module type REPO = sig
  val create_table_if_not_exists :
    Core.Db.connection ->
    (unit, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t

  val get :
    Core.Db.connection ->
    namespace:string ->
    (Model.t option, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t

  val upsert :
    Core.Db.connection ->
    state:Model.t ->
    (unit, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t
end

module Make : functor (Repo : REPO) -> SERVICE

module PostgreSql : SERVICE

val postgresql : Core.Container.Binding.t

val mariadb : Core.Container.Binding.t

module MariaDb : SERVICE

type step = Migration_sig.step

type t = Migration_sig.t

val pp : Format.formatter -> t -> unit

val show : t -> string

val equal : t -> t -> bool

val empty : string -> t

val create_step : label:string -> ?check_fk:bool -> string -> step

val add_step : step -> t -> t

val execute_migration : t -> Core.Db.connection -> (unit, string) Result.t Lwt.t

val execute : t list -> (unit, string) Result.t Lwt.t
