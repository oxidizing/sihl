include Contract_database

let log_src = Logs.Src.create "sihl.service.database"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let main_pool_ref
  : (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt_unix.Pool.t option ref
  =
  ref None
;;

let pools
  : ( string
      , (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt_unix.Pool.t )
      Hashtbl.t
  =
  Hashtbl.create 100
;;

type 'a prepared_search_request =
  { asc_request :
      (int * int, int * 'a, [ `Many | `One | `Zero ]) Caqti_request.t
  ; desc_request :
      (int * int, int * 'a, [ `Many | `One | `Zero ]) Caqti_request.t
  ; filter_asc_request :
      (string * int * int, int * 'a, [ `Many | `One | `Zero ]) Caqti_request.t
  ; filter_desc_request :
      (string * int * int, int * 'a, [ `Many | `One | `Zero ]) Caqti_request.t
  ; format_filter : string -> string
  }

let prepare_requests _ _ _ = failwith "prepare_requests deprecated"
let default_format_filter keyword = "%" ^ keyword ^ "%"

let prepare_search_request
      ~search_query
      ~filter_fragment
      ?(sort_by_field = "id")
      ?(format_filter = default_format_filter)
      output_type
  : 'a prepared_search_request
  =
  let open Caqti_request.Infix in
  let output_type = Caqti_type.(t2 int output_type) in
  let asc_request =
    let input_type = Caqti_type.(t2 int int) in
    let query =
      Printf.sprintf
        "%s ORDER BY %s ASC %s"
        search_query
        sort_by_field
        "LIMIT $1 OFFSET $2"
    in
    query |> input_type ->* output_type
  in
  let desc_request =
    let input_type = Caqti_type.(t2 int int) in
    let query =
      Printf.sprintf
        "%s ORDER BY %s DESC %s"
        search_query
        sort_by_field
        "LIMIT $1 OFFSET $2"
    in
    query |> input_type ->* output_type
  in
  let filter_asc_request =
    let input_type = Caqti_type.(t3 string int int) in
    let query =
      Printf.sprintf
        "%s %s ORDER BY %s ASC %s"
        search_query
        filter_fragment
        sort_by_field
        "LIMIT $2 OFFSET $3"
    in
    query |> input_type ->* output_type
  in
  let filter_desc_request =
    let input_type = Caqti_type.(t3 string int int) in
    let query =
      Printf.sprintf
        "%s %s ORDER BY %s DESC %s"
        search_query
        filter_fragment
        sort_by_field
        "LIMIT $2 OFFSET $3"
    in
    query |> input_type ->* output_type
  in
  { asc_request
  ; desc_request
  ; filter_asc_request
  ; filter_desc_request
  ; format_filter
  }
;;

let run_request _ _ _ _ _ = failwith "prepare_requests deprecated"

type config =
  { url : string
  ; pool_size : int option
  ; skip_default_pool_creation : bool option
  ; choose_pool : string option
  }

let config url pool_size skip_default_pool_creation choose_pool =
  { url; pool_size; skip_default_pool_creation; choose_pool }
;;

let schema =
  let open Conformist in
  make
    [ string
        ~meta:
          "The database connection url. This is the only string that Sihl \
           needs to connect to a database."
        "DATABASE_URL"
    ; optional
        ~meta:
          "The amount of connections in the database connection pool that Sihl \
           manages. If the number is too high, the server might struggle. If \
           the number is too low, your Sihl app performs badly. This can be \
           configured using DATABASE_POOL_SIZE and the default is 5."
        (int ~default:5 "DATABASE_POOL_SIZE")
    ; optional
        ~meta:
          "By default, Sihl assumes one database connection pool to connect to \
           one default application database. This value can be set to [true] \
           to skip the creation of the default connection pool, which is \
           configured using env variables. This is useful if an application \
           uses multiple databases. By default, the value is [false]."
        (bool ~default:false "DATABASE_SKIP_DEFAULT_POOL_CREATION")
    ; optional
        ~meta:
          "The database connection pool name that should be used by default. \
           The main pool is used if no value is set. This value can be \
           overriden by using the pool name in the service context."
        (string "DATABASE_CHOOSE_POOL")
    ]
    config
;;

let print_pool_usage pool =
  let n_connections = Caqti_lwt_unix.Pool.size pool in
  let max_connections =
    Option.value (Core_configuration.read schema).pool_size ~default:10
  in
  Logs.debug (fun m -> m "Pool usage: %i/%i" n_connections max_connections)
;;

let fetch_pool ?(ctx = []) () =
  let chosen_pool_name_ctx = CCList.assoc_opt ~eq:String.equal "pool" ctx in
  let chosen_pool_name_env = (Core_configuration.read schema).choose_pool in
  let chosen_pool_name =
    match chosen_pool_name_ctx, chosen_pool_name_env with
    | Some chosen_pool_name, _ -> Some chosen_pool_name
    | None, Some chosen_pool_name -> Some chosen_pool_name
    | None, None -> None
  in
  let chosen_pool = Option.bind chosen_pool_name (Hashtbl.find_opt pools) in
  match chosen_pool, !main_pool_ref with
  | Some pool, _ -> pool
  | None, Some pool ->
    Logs.debug (fun m -> m "Skipping pool creation, re-using existing pool");
    pool
  | None, None ->
    if
      Option.value
        (Core_configuration.read schema).skip_default_pool_creation
        ~default:false
    then
      Logs.warn (fun m ->
        m
          "DATABASE_SKIP_DEFAULT_POOL_CREATION was set to true, but no pool \
           was defined for querying.");
    let pool_size =
      Option.value (Core_configuration.read schema).pool_size ~default:10
    in
    Logs.info (fun m -> m "Create pool with size %i" pool_size);
    (Core_configuration.read schema).url
    |> Uri.of_string
    |> Caqti_lwt_unix.connect_pool
         ~pool_config:(Caqti_pool_config.create ~max_size:pool_size ())
    |> (function
     | Ok pool ->
       main_pool_ref := Some pool;
       pool
     | Error err ->
       let msg = "Failed to connect to DB pool" in
       Logs.err (fun m -> m "%s %s" msg (Caqti_error.show err));
       raise (Contract_database.Exception ("Failed to create pool: " ^ msg)))
;;

let add_pool ?(pool_size = 10) name database_url =
  database_url
  |> Uri.of_string
  |> Caqti_lwt_unix.connect_pool
       ~pool_config:(Caqti_pool_config.create ~max_size:pool_size ())
  |> function
  | Ok pool ->
    if Option.is_some (Hashtbl.find_opt pools name)
    then (
      let msg =
        Format.sprintf "Connection pool with name '%s' exists already" name
      in
      Logs.err (fun m -> m "%s" msg);
      raise (Contract_database.Exception ("Failed to create pool: " ^ msg)))
    else Hashtbl.add pools name pool
  | Error err ->
    let msg = "Failed to connect to DB pool" in
    Logs.err (fun m -> m "%s %s" msg (Caqti_error.show err));
    raise (Contract_database.Exception ("Failed to create pool: " ^ msg))
;;

let drop_pool name =
  match Hashtbl.find_opt pools name with
  | None ->
    Logs.warn (fun m -> m "Connection pool with name '%s' doesn't exist" name);
    Lwt.return_unit
  | Some connection ->
    let%lwt () = Caqti_lwt_unix.Pool.drain connection in
    let () = Hashtbl.remove pools name in
    Lwt.return_unit
;;

let raise_error err =
  match err with
  | Error err -> raise @@ Contract_database.Exception (Caqti_error.show err)
  | Ok result -> result
;;

let transaction ?ctx f =
  let pool = fetch_pool ?ctx () in
  print_pool_usage pool;
  let%lwt result =
    Caqti_lwt_unix.Pool.use
      (fun connection ->
         Logs.debug (fun m -> m "Fetched connection from pool");
         let (module Connection : Caqti_lwt.CONNECTION) = connection in
         let%lwt start_result = Connection.start () in
         match start_result with
         | Error msg ->
           Logs.debug (fun m ->
             m "Failed to start transaction: %s" (Caqti_error.show msg));
           Lwt.return @@ Error msg
         | Ok () ->
           Logs.debug (fun m -> m "Started transaction");
           Lwt.catch
             (fun () ->
                let%lwt result = f connection in
                let%lwt commit_result = Connection.commit () in
                match commit_result with
                | Ok () ->
                  Logs.debug (fun m -> m "Successfully committed transaction");
                  Lwt.return @@ Ok result
                | Error error ->
                  Logs.err (fun m ->
                    m
                      "Failed to commit transaction: %s"
                      (Caqti_error.show error));
                  Lwt.fail
                  @@ Contract_database.Exception "Failed to commit transaction")
             (fun e ->
                let%lwt rollback_result = Connection.rollback () in
                match rollback_result with
                | Ok () ->
                  Logs.debug (fun m -> m "Successfully rolled back transaction");
                  Lwt.fail e
                | Error error ->
                  Logs.err (fun m ->
                    m
                      "Failed to rollback transaction: %s"
                      (Caqti_error.show error));
                  Lwt.fail
                  @@ Contract_database.Exception
                       "Failed to rollback transaction"))
      pool
  in
  match result with
  | Ok result -> Lwt.return result
  | Error error ->
    let msg = Caqti_error.show error in
    Logs.err (fun m -> m "%s" msg);
    Lwt.fail (Contract_database.Exception msg)
;;

let transaction' ?ctx f = transaction ?ctx f |> Lwt.map raise_error

let run_search_request
      ?ctx
      (r : 'a prepared_search_request)
      (sort : [ `Asc | `Desc ])
      (filter : string option)
      ~(limit : int)
      ~(offset : int)
  =
  transaction' ?ctx (fun connection ->
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let%lwt result =
      match sort, filter with
      | `Asc, None -> Connection.collect_list r.asc_request (limit, offset)
      | `Desc, None -> Connection.collect_list r.desc_request (limit, offset)
      | `Asc, Some filter ->
        Connection.collect_list
          r.filter_asc_request
          (r.format_filter filter, limit, offset)
      | `Desc, Some filter ->
        Connection.collect_list
          r.filter_desc_request
          (r.format_filter filter, limit, offset)
    in
    let things = Result.map (List.map snd) result in
    let total =
      Result.map
        (fun e ->
           e |> List.map fst |> CCList.head_opt |> Option.value ~default:0)
        result
    in
    CCResult.both things total |> Lwt.return)
;;

let query ?ctx f =
  let pool = fetch_pool ?ctx () in
  print_pool_usage pool;
  let%lwt result =
    Caqti_lwt_unix.Pool.use
      (fun connection -> f connection |> Lwt.map Result.ok)
      pool
  in
  match result with
  | Ok result -> Lwt.return result
  | Error error ->
    let msg = Caqti_error.show error in
    Logs.err (fun m -> m "%s" msg);
    Lwt.fail (Contract_database.Exception msg)
;;

let query' ?ctx f = query ?ctx f |> Lwt.map raise_error

let find_opt ?ctx request input =
  query' ?ctx (fun connection ->
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    Connection.find_opt request input)
;;

let find ?ctx request input =
  query' ?ctx (fun connection ->
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    Connection.find request input)
;;

let collect ?ctx request input =
  query' ?ctx (fun connection ->
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    Connection.collect_list request input)
;;

let exec ?ctx request input =
  query' ?ctx (fun connection ->
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    Connection.exec request input)
;;

let used_database () =
  let host =
    (Core_configuration.read schema).url |> Uri.of_string |> Uri.host
  in
  match host with
  | Some "mariadb" -> Some Contract_database.MariaDb
  | Some "mysql" -> Some Contract_database.MariaDb
  | Some "postgresql" | Some "postgres" | Some "pg" ->
    Some Contract_database.PostgreSql
  | Some not_supported ->
    Logs.warn (fun m -> m "Unsupported database %s found" not_supported);
    None
  | None -> None
;;

(* Service lifecycle *)

let start () =
  let skip_default_pool_creation =
    Option.value
      (Core_configuration.read schema).skip_default_pool_creation
      ~default:false
  in
  if skip_default_pool_creation
  then Lwt.return ()
  else (
    (* Make sure the default database is online when starting service. *)
    let _ = fetch_pool () in
    Lwt.return ())
;;

let stop () = Lwt.return ()

let lifecycle =
  Core_container.create_lifecycle Contract_database.name ~start ~stop
;;

let register () =
  let configuration = Core_configuration.make ~schema () in
  Core_container.Service.create ~configuration lifecycle
;;
