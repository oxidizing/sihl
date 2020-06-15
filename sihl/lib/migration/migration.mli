module Model : sig
  type t
end

module type SERVICE = sig
  val setup : Core.Db.connection -> (unit, string) Lwt_result.t

  val has :
    Core.Db.connection -> namespace:string -> (bool, string) Lwt_result.t

  val get :
    Core.Db.connection -> namespace:string -> (Model.t, string) Lwt_result.t

  val upsert : Core.Db.connection -> Model.t -> (unit, string) Lwt_result.t

  val mark_dirty :
    Core.Db.connection -> namespace:string -> (Model.t, string) Lwt_result.t

  val mark_clean :
    Core.Db.connection -> namespace:string -> (Model.t, string) Lwt_result.t

  val increment :
    Core.Db.connection -> namespace:string -> (Model.t, string) Lwt_result.t
end

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

val postgresql : Core.Registry.Binding.t

val mariadb : Core.Registry.Binding.t

module MariaDb : SERVICE

type step

type t

val empty : string -> t

val create_step : label:string -> string -> step

val add_step : step -> t -> t

val execute_migration : t -> Core.Db.connection -> (unit, string) Result.t Lwt.t

val execute : t list -> (unit, string) Result.t Lwt.t
