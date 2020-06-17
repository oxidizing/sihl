val render :
  Opium_kernel.Request.t ->
  Sihl.Email.t ->
  (Sihl.Email.t, Sihl.Error.t) Lwt_result.t

module Console : Sihl.Email.SERVICE

module Smtp : Sihl.Email.SERVICE

module SendGrid : Sihl.Email.SERVICE

module Memory : sig
  val send :
    Opium_kernel.Request.t -> Sihl.Email.t -> (unit, Sihl.Error.t) result Lwt.t

  val get : unit -> Sihl.Email.t
end

val send :
  Opium_kernel.Request.t -> Sihl.Email.t -> (unit, Sihl.Error.t) result Lwt.t
