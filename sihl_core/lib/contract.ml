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
  module type MIGRATION = sig
    val migration : unit -> Db_migration_core.migration
  end

  module type REPOSITORY = sig
    val create_table_if_not_exists :
      (module Caqti_lwt.CONNECTION) ->
      unit ->
      (unit, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t

    val get :
      (module Caqti_lwt.CONNECTION) ->
      namespace:string ->
      ( Db_migration_core.Model.t option,
        [> Caqti_error.call_or_retrieve ] )
      Result.t
      Lwt.t

    val upsert :
      (module Caqti_lwt.CONNECTION) ->
      Db_migration_core.Model.t ->
      (unit, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t
  end

  let repository : (module REPOSITORY) Registry.Key.t =
    Registry.Key.create "migration repository"
end
