type database_type =
  | MariaDb
  | PostgreSql

(* Signature *)
let name = "database"

exception Exception of string

module type Sig = sig
  val prepare_requests
    :  string
    -> string
    -> string
    -> string
    -> 'a Caqti_type.t
    -> (int, 'a, [ `Many | `One | `Zero ]) Caqti_request.t
       * (int, 'a, [ `Many | `One | `Zero ]) Caqti_request.t
       * (string * int, 'a, [ `Many | `One | `Zero ]) Caqti_request.t
       * (string * int, 'a, [ `Many | `One | `Zero ]) Caqti_request.t
       * (unit, int, [< `Many | `One | `Zero > `One ]) Caqti_request.t

  val run_request
    :  (module Caqti_lwt.CONNECTION)
    -> ('a, 'b, [< `Many | `One | `Zero ]) Caqti_request.t
       * ('a, 'b, [< `Many | `One | `Zero ]) Caqti_request.t
       * ('c * 'a, 'b, [< `Many | `One | `Zero ]) Caqti_request.t
       * ('c * 'a, 'b, [< `Many | `One | `Zero ]) Caqti_request.t
       * (unit, int, [< `One ]) Caqti_request.t
    -> [< `Asc | `Desc ]
    -> 'c option
    -> 'a
    -> ('b list * int) Lwt.t

  (** [raise_error err] raises a printable caqti error [err] .*)
  val raise_error : ('a, Caqti_error.t) Result.t -> 'a

  (** [fetch_pool ()] returns the connection pool that was set up. If there was
      no connection pool set up, setting it up now. *)
  val fetch_pool
    :  unit
    -> (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt.Pool.t

  (** [query f] runs the query [f] on the connection pool and returns the
      result. If the query fails the Lwt.t fails as well. *)
  val query : (Caqti_lwt.connection -> 'a Lwt.t) -> 'a Lwt.t

  (** [query' f] runs the query [f] on the connection pool and returns the
      result. Use [query'] instead of {!query} as a shorthand when you have a
      single caqti request to execute. *)
  val query'
    :  (Caqti_lwt.connection -> ('a, Caqti_error.t) Result.t Lwt.t)
    -> 'a Lwt.t

  (** [transaction f] runs the query [f] on the connection pool in a transaction
      and returns the result. If the query fails the Lwt.t fails as well and the
      transaction gets rolled back. If the database driver doesn't support
      transactions, [transaction] gracefully becomes {!query}. *)
  val transaction : (Caqti_lwt.connection -> 'a Lwt.t) -> 'a Lwt.t

  (** [transaction' f] runs the query [f] on the connection pool in a
      transaction and returns the result. If the query fails the Lwt.t fails as
      well and the transaction gets rolled back. If the database driver doesn't
      support transactions, [transaction'] gracefully becomes {!query'}. *)
  val transaction'
    :  (Caqti_lwt.connection -> ('a, Caqti_error.t) Result.t Lwt.t)
    -> 'a Lwt.t

  val register : unit -> Core_container.Service.t

  include Core_container.Service.Sig
end
