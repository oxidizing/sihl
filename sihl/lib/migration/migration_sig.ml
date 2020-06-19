module type REPO = sig
  val create_table_if_not_exists :
    Core.Db.connection ->
    (unit, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t

  val get :
    Core.Db.connection ->
    namespace:string ->
    (Migration_model.t option, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t

  val upsert :
    Core.Db.connection ->
    state:Migration_model.t ->
    (unit, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t
end

module type SERVICE = sig
  include Sig.SERVICE

  val setup : Core.Db.connection -> (unit, string) Lwt_result.t

  val has :
    Core.Db.connection -> namespace:string -> (bool, string) Lwt_result.t

  val get :
    Core.Db.connection ->
    namespace:string ->
    (Migration_model.t, string) Lwt_result.t

  val upsert :
    Core.Db.connection -> Migration_model.t -> (unit, string) Lwt_result.t

  val mark_dirty :
    Core.Db.connection ->
    namespace:string ->
    (Migration_model.t, string) Lwt_result.t

  val mark_clean :
    Core.Db.connection ->
    namespace:string ->
    (Migration_model.t, string) Lwt_result.t

  val increment :
    Core.Db.connection ->
    namespace:string ->
    (Migration_model.t, string) Lwt_result.t
end
