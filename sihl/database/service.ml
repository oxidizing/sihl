open Lwt.Syntax
open Model

module Default : Sig.SERVICE = struct
  let print_pool_usage pool =
    let n_connections = Caqti_lwt.Pool.size pool in
    let max_connections =
      Option.value (Core.Configuration.read_int "DATABASE_POOL_SIZE") ~default:10
    in
    Logs.debug (fun m -> m "DB: Pool usage: %i/%i" n_connections max_connections)
  ;;

  let create_pool () =
    match !pool_ref with
    | Some pool ->
      Logs.debug (fun m -> m "DB: Skipping pool creation, re-using existing pool");
      pool
    | None ->
      let pool_size =
        Option.value (Core.Configuration.read_int "DATABASE_POOL_SIZE") ~default:10
      in
      Logs.debug (fun m -> m "DB: Create pool with size %i" pool_size);
      Option.get ("DATABASE_URL" |> Core.Configuration.read_string)
      |> Uri.of_string
      |> Caqti_lwt.connect_pool ~max_size:pool_size
      |> (function
      | Ok pool ->
        pool_ref := Some pool;
        pool
      | Error err ->
        let msg = "DB: Failed to connect to DB pool" in
        Logs.err (fun m -> m "%s %s" msg (Caqti_error.show err));
        raise (Exception ("DB: Failed to create pool " ^ msg)))
  ;;

  let ctx_with_pool () =
    let pool = create_pool () in
    Core.Ctx.(empty |> add_pool pool)
  ;;

  let add_pool ctx =
    let pool = create_pool () in
    add_pool pool ctx
  ;;

  let query ctx f =
    match find_transaction ctx, find_connection ctx, find_pool ctx with
    | Some connection, None, None ->
      let* result = f connection in
      (match result with
      | Ok result -> Lwt.return result
      | Error error ->
        let msg = Caqti_error.show error in
        Logs.err (fun m -> m "DB: %s" msg);
        Lwt.fail (Exception msg))
    | None, Some connection, _ ->
      let* result = f connection in
      (match result with
      | Ok result -> Lwt.return result
      | Error error ->
        let msg = Caqti_error.show error in
        Logs.err (fun m -> m "DB: %s" msg);
        Lwt.fail (Exception msg))
    | None, None, Some pool ->
      print_pool_usage pool;
      let* result = Caqti_lwt.Pool.use f pool in
      (match result with
      | Ok result -> Lwt.return result
      | Error error ->
        let msg = Caqti_error.show error in
        Logs.err (fun m -> m "DB: %s" msg);
        Lwt.fail (Exception msg))
    | Some _, Some _, Some _ ->
      Logs.err (fun m ->
          m
            "DB: Connection AND transaction AND pool found in context, this should never \
             happen and might indicate connection leaks. Please report this issue.");
      Lwt.fail (Exception "Connection and pool found")
    | _ ->
      Logs.err (fun m -> m "DB: No connection pool found");
      Logs.info (fun m -> m "DB: Have you applied the DB middleware?");
      Lwt.fail (Exception "No connection pool found")
  ;;

  let with_connection ctx f =
    match find_transaction ctx, find_connection ctx, find_pool ctx with
    | Some _, None, None -> ctx |> remove_pool |> f
    | None, Some _, None -> ctx |> remove_pool |> f
    | None, None, Some pool ->
      print_pool_usage pool;
      let* pool_result =
        Caqti_lwt.Pool.use
          (fun connection ->
            Logs.debug (fun m -> m "DB TX: Fetched connection from pool");
            let (module Connection : Caqti_lwt.CONNECTION) = connection in
            let ctx_with_connection =
              ctx |> remove_pool |> add_connection (module Connection)
            in
            Lwt.catch
              (fun () ->
                let* result = f ctx_with_connection in
                Lwt.return @@ Ok result)
              (fun e -> Lwt.fail e))
          pool
      in
      (match pool_result with
      | Ok result ->
        (* All good, return result of f ctx *)
        Lwt.return result
      | Error pool_err ->
        (* Failed to start, commit or rollback transaction *)
        Lwt.fail (Exception (pool_err |> Caqti_error.show)))
    | Some _, Some _, Some _ ->
      Logs.err (fun m ->
          m
            "DB: Connection AND transaction AND pool found in context, this should never \
             happen and might indicate connection leaks. Please report this issue.");
      Lwt.fail (Exception "Connection and pool found")
    | _ ->
      Logs.err (fun m -> m "No connection pool found");
      Logs.info (fun m -> m "Have you applied the DB middleware?");
      Lwt.fail (Exception "No connection pool found")
  ;;

  let atomic ctx f =
    match find_transaction ctx, find_connection ctx, find_pool ctx with
    | Some connection, None, None ->
      (* Make sure [f] can not use the pool or some other connection *)
      ctx |> remove_pool |> remove_connection |> add_transaction connection |> f
    | None, Some connection, None ->
      (* TODO start transaction and store current connection as transaction in trx *)
      let (module Connection : Caqti_lwt.CONNECTION) = connection in
      let* start_result = Connection.start () in
      (match start_result with
      | Error msg ->
        Logs.debug (fun m ->
            m "DB TX: Failed to start transaction %s" (Caqti_error.show msg));
        Lwt.fail @@ Exception (Caqti_error.show msg)
      | Ok () ->
        Logs.debug (fun m -> m "DB TX: Started transaction");
        (* Remove the pool so that all subsequent queries are executed on the connection.
           A transaction can only be done only at one connection, it can not span multiple
           connections. *)
        let ctx_with_connection =
          ctx |> remove_pool |> remove_connection |> add_transaction (module Connection)
        in
        Lwt.catch
          (fun () ->
            let* result = f ctx_with_connection in
            let* commit_result = Connection.commit () in
            match commit_result with
            | Ok () ->
              Logs.debug (fun m -> m "DB TX: Successfully committed transaction");
              Lwt.return @@ result
            | Error error ->
              Logs.err (fun m ->
                  m "DB TX: Failed to commit transaction %s" (Caqti_error.show error));
              Lwt.fail @@ Exception "Failed to commit transaction")
          (fun e ->
            let* rollback_result = Connection.rollback () in
            match rollback_result with
            | Ok () ->
              Logs.debug (fun m -> m "DB TX: Successfully rolled back transaction");
              Lwt.fail e
            | Error error ->
              Logs.err (fun m ->
                  m "DB TX: Failed to rollback transaction %s" (Caqti_error.show error));
              Lwt.fail @@ Exception "Failed to rollback transaction"))
    | None, None, Some pool ->
      (* There is no transaction active, create a new one *)
      print_pool_usage pool;
      let* pool_result =
        Caqti_lwt.Pool.use
          (fun connection ->
            Logs.debug (fun m -> m "DB TX: Fetched connection from pool");
            let (module Connection : Caqti_lwt.CONNECTION) = connection in
            let* start_result = Connection.start () in
            match start_result with
            | Error msg ->
              Logs.debug (fun m ->
                  m "DB TX: Failed to start transaction %s" (Caqti_error.show msg));
              Lwt.return @@ Error msg
            | Ok () ->
              Logs.debug (fun m -> m "DB TX: Started transaction");
              (* Remove the pool so that all subsequent queries are executed on the
                 connection. A transaction can only be done only at one connection, it can
                 not span multiple connections. *)
              let ctx_with_connection =
                ctx
                |> remove_pool
                |> remove_connection
                |> add_transaction (module Connection)
              in
              Lwt.catch
                (fun () ->
                  let* result = f ctx_with_connection in
                  let* commit_result = Connection.commit () in
                  match commit_result with
                  | Ok () ->
                    Logs.debug (fun m -> m "DB TX: Successfully committed transaction");
                    Lwt.return @@ Ok result
                  | Error error ->
                    Logs.err (fun m ->
                        m
                          "DB TX: Failed to commit transaction %s"
                          (Caqti_error.show error));
                    Lwt.fail @@ Exception "Failed to commit transaction")
                (fun e ->
                  let* rollback_result = Connection.rollback () in
                  match rollback_result with
                  | Ok () ->
                    Logs.debug (fun m -> m "DB TX: Successfully rolled back transaction");
                    Lwt.fail e
                  | Error error ->
                    Logs.err (fun m ->
                        m
                          "DB TX: Failed to rollback transaction %s"
                          (Caqti_error.show error));
                    Lwt.fail @@ Exception "Failed to rollback transaction"))
          pool
      in
      (match pool_result with
      | Ok result ->
        (* All good, return result of f ctx *)
        Lwt.return result
      | Error pool_err ->
        (* Failed to start, commit or rollback transaction *)
        Lwt.fail (Exception (pool_err |> Caqti_error.show)))
    | Some _, Some _, Some _ ->
      Logs.err (fun m ->
          m
            "DB: Connection AND transaction AND pool found in context, this should never \
             happen and might indicate connection leaks. Please report this issue.");
      Lwt.fail (Exception "Connection and pool found")
    | _ ->
      Logs.err (fun m -> m "No connection pool found");
      Logs.info (fun m -> m "Have you applied the DB middleware?");
      Lwt.fail (Exception "No connection pool found")
  ;;

  let set_fk_check_request =
    Caqti_request.exec Caqti_type.bool "SET FOREIGN_KEY_CHECKS = ?;"
  ;;

  let set_fk_check ctx ~check =
    query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec set_fk_check_request check)
  ;;

  let with_disabled_fk_check ctx f =
    with_connection ctx (fun ctx ->
        let* () = set_fk_check ctx ~check:false in
        Lwt.finalize (fun () -> f ctx) (fun () -> set_fk_check ctx ~check:true))
  ;;

  let start ctx = ctx |> add_pool |> Lwt.return
  let stop _ = Lwt.return ()
  let lifecycle = Core.Container.Lifecycle.create "db" ~start ~stop

  let configure configuration =
    let configuration = Core.Configuration.make configuration in
    Core.Container.Service.create ~configuration lifecycle
  ;;
end
