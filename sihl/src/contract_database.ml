type database =
  | MariaDb
  | PostgreSql

(* Signature *)
let name = "database"

exception Exception of string

module type Sig = sig
  (** ['a prepared_search_request] is a prepared SQL statement that can be used
      to sort, filter and paginate (= search) a collection. *)
  type 'a prepared_search_request

  val prepare_requests : string -> string -> string -> string
  (* Deprecated in 0.6.0 *)
  [@@deprecated "Use prepare_search_request instead"]

  (** [prepare_search_request ~search_query ~count_query ~filter_fragment ?sort_by_field type]
      returns a prepared SQL statement ['a prepared_search_request] by
      assembling the SQL query from the provided fragments.

      [search_query] is the [SELECT ... FROM table] part of the query.

      [count_query] is a query that is executed by Sihl after the search in
      order to obtain the total number of items in the table. For example
      [SELECT COUNT(\*\) FROM table].

      [filter_fragment] is the fragment that is appended to [search_query] for
      filtering. Usually you want ot [OR] fields that are often searched for.
      For example
      [WHERE table.field1 LIKE $1 OR table.field2 $1 OR table.field3 LIKE $1].

      [sort_by_field] is an optional field name that is used for sorting. By
      default, the field "id" is used. Note that in order to prepare the
      requests, the sort field has to be known beforehand. If you want to
      dynamically set the field, you need to write your own query at runtime.

      [format_filter] is a function applied to the filter keyword before it is
      passed to the database. By default, a keyword "keyword" is formatted to
      "%skeyword%s". This might not be what you want performance-wise. If you
      need full control, pass in the identity function and format the keyword
      yourself.

      [type] is the caqti type of an item of the collection. *)
  val prepare_search_request
    :  search_query:string
    -> filter_fragment:string
    -> ?sort_by_field:string
    -> ?format_filter:(string -> string)
    -> 'a Caqti_type.t
    -> 'a prepared_search_request

  val run_request
    :  (module Caqti_lwt.CONNECTION)
    -> 'a prepared_search_request
    -> [< `Asc | `Desc ]
    -> 'c option
    -> 'a
    -> ('b list * int) Lwt.t
  (* Deprecated in 0.6.0 *)
  [@@deprecated "Use run_search_request instead"]

  (** [run_search_request ?ctx prepared_request sort filter ~limit ~offset] runs
      the [prepared_request] and returns a partial result of the whole stored
      collection. The second element of the result tuple is the total amount of
      items in the whole collection.

      [prepared_request] is the returned prepared request by
      {!prepare_search_request}.

      [sort] is the sort order. The field that is sorted by was set by
      {!prepare_search_request}.

      [filter] is an optional keyword that is used to filter the collection. If
      no filter is provided, the collection is not filtered.

      [offset] is the number of items that the returned partial result is offset
      by.

      [limit] is the number of items of the returned partial result.

      [offset] and [limit] can be used together to implement pagination.

      An optional [ctx] can be provided. The tuple [("pool", "pool_name")]
      selects the pool ["pool_name"]. Make sure to initialize the pool with
      {!add_pool} beforehand. *)
  val run_search_request
    :  ?ctx:(string * string) list
    -> 'a prepared_search_request
    -> [ `Asc | `Desc ]
    -> string option
    -> limit:int
    -> offset:int
    -> ('a list * int) Lwt.t

  (** [raise_error err] raises a printable caqti error [err] .*)
  val raise_error : ('a, Caqti_error.t) Result.t -> 'a

  (** [fetch_pool ?ctx ()] returns the connection pool referenced in [ctx] or
      the default connection pool if no connection pool is referenced.

      An optional [ctx] can be provided. The tuple [("pool", "pool_name")]
      selects the pool ["pool_name"]. Make sure to initialize the pool with
      {!add_pool} beforehand. *)
  val fetch_pool
    :  ?ctx:(string * string) list
    -> unit
    -> (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt_unix.Pool.t

  (** [add_pool ~pool_size name database_url] creates a connection pool with a
      unique [name]. Creation fails if a pool with the same name was already
      created to avoid overwriting connection pools accidentally. The connection
      to the database is established.

      The pool can be referenced with its [name]. The service context can
      contain the pool name under the key `pool` to force the usage of a certain
      pool.

      A [pool_size] can be provided to define the number of connections that
      should be kept open. The default is 10. *)
  val add_pool : ?pool_size:int -> string -> string -> unit

  (** [drop_pool name] closes all resources for the pool.

      The pool can be referenced with its [name]. The service context can
      contain the pool name under the key `pool` to force the usage of a certain
      pool. *)
  val drop_pool : string -> unit Lwt.t

  (** [find_opt ?ctx request input] runs a caqti [request] where [input] is the
      input of the caqti request and returns one row or [None]. Returns [None]
      if no rows are found.

      Note that the caqti request is only allowed to return one or zero rows,
      not many.

      An optional [ctx] can be provided. The tuple [("pool", "pool_name")]
      selects the pool ["pool_name"]. Make sure to initialize the pool with
      {!add_pool} beforehand. *)

  val find_opt
    :  ?ctx:(string * string) list
    -> ('a, 'b, [< `One | `Zero ]) Caqti_request.t
    -> 'a
    -> 'b option Lwt.t

  (** [find ?ctx request input] runs a caqti [request] where [input] is the
      input of the caqti request and returns one row. Raises an exception if no
      row was found.

      Note that the caqti request is only allowed to return one or zero rows,
      not many.

      An optional [ctx] can be provided. The tuple [("pool", "pool_name")]
      selects the pool ["pool_name"]. Make sure to initialize the pool with
      {!add_pool} beforehand. *)
  val find
    :  ?ctx:(string * string) list
    -> ('a, 'b, [< `One ]) Caqti_request.t
    -> 'a
    -> 'b Lwt.t

  (** [collect ?ctx request input] runs a caqti [request] where [input] is the
      input of the caqti request and retuns a list of rows.

      Note that the caqti request is allowed to return one, zero or many rows.

      An optional [ctx] can be provided. The tuple [("pool", "pool_name")]
      selects the pool ["pool_name"]. Make sure to initialize the pool with
      {!add_pool} beforehand. *)
  val collect
    :  ?ctx:(string * string) list
    -> ('a, 'b, [< `One | `Zero | `Many ]) Caqti_request.t
    -> 'a
    -> 'b list Lwt.t

  (** [exec ?ctx request input] runs a caqti [request].

      Note that the caqti request is not allowed to return any rows.

      Use {!exec} to run mutations.

      An optional [ctx] can be provided. The tuple [("pool", "pool_name")]
      selects the pool ["pool_name"]. Make sure to initialize the pool with
      {!add_pool} beforehand. *)
  val exec
    :  ?ctx:(string * string) list
    -> ('b, unit, [< `Zero ]) Caqti_request.t
    -> 'b
    -> unit Lwt.t

  (** [query ?ctx f] runs the query [f] and returns the result. If the query
      fails the Lwt.t fails as well.

      An optional [ctx] can be provided. The tuple [("pool", "pool_name")]
      selects the pool ["pool_name"]. Make sure to initialize the pool with
      {!add_pool} beforehand. *)
  val query
    :  ?ctx:(string * string) list
    -> (Caqti_lwt.connection -> 'a Lwt.t)
    -> 'a Lwt.t

  (** [query' ?ctx f] runs the query [f] and returns the result. Use [query']
      instead of {!query} as a shorthand when you have a single caqti request to
      execute.

      An optional [ctx] can be provided. The tuple [("pool", "pool_name")]
      selects the pool ["pool_name"]. Make sure to initialize the pool with
      {!add_pool} beforehand. *)
  val query'
    :  ?ctx:(string * string) list
    -> (Caqti_lwt.connection -> ('a, Caqti_error.t) Result.t Lwt.t)
    -> 'a Lwt.t

  (** [transaction ?ctx f] runs the query [f] in a transaction and returns the
      result. If the query fails the Lwt.t fails as well and the transaction
      gets rolled back. If the database driver doesn't support transactions,
      [transaction] gracefully becomes {!query}.

      An optional [ctx] can be provided. The tuple [("pool", "pool_name")]
      selects the pool ["pool_name"]. Make sure to initialize the pool with
      {!add_pool} beforehand. *)
  val transaction
    :  ?ctx:(string * string) list
    -> (Caqti_lwt.connection -> 'a Lwt.t)
    -> 'a Lwt.t

  (** [transaction' ?ctx f] runs the query [f] in a transaction and returns the
      result. If the query fails the Lwt.t fails as well and the transaction
      gets rolled back. If the database driver doesn't support transactions,
      [transaction'] gracefully becomes {!query'}.

      An optional [ctx] can be provided. The tuple [("pool", "pool_name")]
      selects the pool ["pool_name"]. Make sure to initialize the pool with
      {!add_pool} beforehand. *)
  val transaction'
    :  ?ctx:(string * string) list
    -> (Caqti_lwt.connection -> ('a, Caqti_error.t) Result.t Lwt.t)
    -> 'a Lwt.t

  val register : unit -> Core_container.Service.t

  include Core_container.Service.Sig
end
