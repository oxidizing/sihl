module Model : sig
  type t
end

module type SERVICE = sig
  val setup :
    ( (module Caqti_lwt.CONNECTION),
      [< Caqti_error.t > `Decode_rejected
      `Encode_failed
      `Encode_rejected
      `Request_failed
      `Request_rejected
      `Response_failed
      `Response_rejected ] )
    Caqti_lwt.Pool.t ->
    (unit, string) Lwt_result.t

  val has :
    ( (module Caqti_lwt.CONNECTION),
      [< Caqti_error.t > `Decode_rejected
      `Encode_failed
      `Encode_rejected
      `Request_failed
      `Request_rejected
      `Response_failed
      `Response_rejected ] )
    Caqti_lwt.Pool.t ->
    namespace:string ->
    (bool, string) Lwt_result.t

  val get :
    ( (module Caqti_lwt.CONNECTION),
      [< Caqti_error.t > `Decode_rejected
      `Encode_failed
      `Encode_rejected
      `Request_failed
      `Request_rejected
      `Response_failed
      `Response_rejected ] )
    Caqti_lwt.Pool.t ->
    namespace:string ->
    (Model.t, string) Lwt_result.t

  val upsert :
    ( (module Caqti_lwt.CONNECTION),
      [< Caqti_error.t > `Decode_rejected
      `Encode_failed
      `Encode_rejected
      `Request_failed
      `Request_rejected
      `Response_failed
      `Response_rejected ] )
    Caqti_lwt.Pool.t ->
    Model.t ->
    (unit, string) Lwt_result.t

  val mark_dirty :
    ( (module Caqti_lwt.CONNECTION),
      [< Caqti_error.t > `Decode_rejected
      `Encode_failed
      `Encode_rejected
      `Request_failed
      `Request_rejected
      `Response_failed
      `Response_rejected ] )
    Caqti_lwt.Pool.t ->
    namespace:string ->
    (Model.t, string) Lwt_result.t

  val mark_clean :
    ( (module Caqti_lwt.CONNECTION),
      [< Caqti_error.t > `Decode_rejected
      `Encode_failed
      `Encode_rejected
      `Request_failed
      `Request_rejected
      `Response_failed
      `Response_rejected ] )
    Caqti_lwt.Pool.t ->
    namespace:string ->
    (Model.t, string) Lwt_result.t

  val increment :
    ( (module Caqti_lwt.CONNECTION),
      [< Caqti_error.t > `Decode_rejected
      `Encode_failed
      `Encode_rejected
      `Request_failed
      `Request_rejected
      `Response_failed
      `Response_rejected ] )
    Caqti_lwt.Pool.t ->
    namespace:string ->
    (Model.t, string) Lwt_result.t
end

module type REPO = sig
  val create_table_if_not_exists :
    (module Caqti_lwt.CONNECTION) ->
    unit ->
    (unit, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t

  val get :
    (module Caqti_lwt.CONNECTION) ->
    namespace:string ->
    (Model.t option, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t

  val upsert :
    (module Caqti_lwt.CONNECTION) ->
    Model.t ->
    (unit, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t
end

module Make : functor (Repo : REPO) -> SERVICE

module PostgreSql : SERVICE

module MariaDb : SERVICE

type t

val execute : t list -> (unit, string) result Lwt.t
