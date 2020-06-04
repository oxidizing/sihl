module Email = struct
  module type EMAIL = sig
    type email

    val send : Opium.Std.Request.t -> email -> (unit, string) result Lwt.t

    (* val queue : Opium.Std.Request.t -> email -> (unit, string) result Lwt.t *)
  end

  module type REPOSITORY = sig
    (* TODO *)
  end
end

module Migration = struct
  open Base

  type migration_error = Caqti_error.t

  type migration_operation =
    Caqti_lwt.connection -> (unit, migration_error) Result.t Lwt.t

  type migration_step = string * migration_operation

  type migration = string * migration_step list

  module type MIGRATION = sig
    val migration : unit -> migration
  end

  module State = struct
    type t = { namespace : string; version : int; dirty : bool }
  end

  module type REPOSITORY = sig
    val create_table_if_not_exists :
      (module Caqti_lwt.CONNECTION) ->
      unit ->
      (unit, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t

    val get :
      (module Caqti_lwt.CONNECTION) ->
      namespace:string ->
      (State.t option, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t

    val upsert :
      (module Caqti_lwt.CONNECTION) ->
      State.t ->
      (unit, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t
  end

  let repository : (module REPOSITORY) Core_registry.Key.t =
    Core_registry.Key.create "migration repository"
end

module type REPOSITORY = sig
  val migrate : unit -> Migration.migration

  val clean : Core_db.connection -> unit Core_db.db_result
end
