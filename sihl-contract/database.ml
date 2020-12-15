module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** [raise_error err] raises a printable caqti error [err] .*)
  val raise_error : ('a, Caqti_error.t) Result.t -> 'a

  (** [fetch_pool ()] returns the connection pool. *)
  val fetch_pool : unit -> (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt.Pool.t

  (** [query ctx f] runs the query [f] on the connection pool and returns the result. If
      the query fails the Lwt.t fails as well. *)
  val query : (Caqti_lwt.connection -> 'a Lwt.t) -> 'a Lwt.t

  (** [transaction ctx f] runs the query [f] on the connection pool in a transaction and
      returns the result. If the query fails the Lwt.t fails as well and the transaction
      gets rolled back. If the database driver doesn't support transactions, [transaction]
      gracefully becomes [query]. *)
  val transaction : (Caqti_lwt.connection -> 'a Lwt.t) -> 'a Lwt.t

  val register : unit -> Sihl_core.Container.Service.t
end
