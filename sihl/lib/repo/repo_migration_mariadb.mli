val create_table_if_not_exists :
  (module Caqti_lwt.CONNECTION) ->
  unit ->
  (unit, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t

val get :
  (module Caqti_lwt.CONNECTION) ->
  namespace:string ->
  ( Core.Contract.Migration.State.t option,
    [> Caqti_error.call_or_retrieve ] )
  Result.t
  Lwt.t

val upsert :
  (module Caqti_lwt.CONNECTION) ->
  Core.Contract.Migration.State.t ->
  (unit, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t
