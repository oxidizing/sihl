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

  (** [prepare_search_request ~search_query ~count_query ~filter_fragment
      ?sort_by_field type]
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

      [type] is the caqti type of an item of the collection. *)
  val prepare_search_request
    :  search_query:string
    -> count_query:string
    -> filter_fragment:string
    -> ?sort_by_field:string
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

  (** [run_search_request prepared_request sort filter ~limit ~offset] runs the
      [prepared_request] and returns a partial result of the whole stored
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

      [offset] and [limit] can be used together to implement pagination. *)
  val run_search_request
    :  'a prepared_search_request
    -> [ `Asc | `Desc ]
    -> string option
    -> limit:int
    -> offset:int
    -> ('a list * int) Lwt.t

  (** [raise_error err] raises a printable caqti error [err] .*)
  val raise_error : ('a, Caqti_error.t) Result.t -> 'a

  (** [fetch_pool ()] returns the connection pool that was set up. If there was
      no connection pool set up, setting it up now. *)
  val fetch_pool
    :  unit
    -> (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt.Pool.t

  (** [find_opt request input] runs a caqti [request] in the connection pool
      where [input] is the input of the caqti request and returns one row or
      [None]. Returns [None] if no rows are found.

      Note that the caqti request is only allowed to return one or zero rows,
      not many. *)
  val find_opt
    :  ('a, 'b, [< `One | `Zero ]) Caqti_request.t
    -> 'a
    -> 'b option Lwt.t

  (** [find request input] runs a caqti [request] on the connection pool where
      [input] is the input of the caqti request and returns one row. Raises an
      exception if no row was found.

      Note that the caqti request is only allowed to return one or zero rows,
      not many. *)
  val find : ('a, 'b, [< `One ]) Caqti_request.t -> 'a -> 'b Lwt.t

  (** [collect request input] runs a caqti [request] on the connection pool
      where [input] is the input of the caqti request and retuns a list of rows.

      Note that the caqti request is allowed to return one, zero or many rows. *)
  val collect
    :  ('a, 'b, [< `One | `Zero | `Many ]) Caqti_request.t
    -> 'a
    -> 'b list Lwt.t

  (** [exec request input] runs a caqti [request] on the connection pool.

      Note that the caqti request is not allowed to return any rows.

      Use {!exec} to run mutations. *)
  val exec : ('b, unit, [< `Zero ]) Caqti_request.t -> 'b -> unit Lwt.t

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
