open Base
open Lwt.Syntax
open Data_db_core

module Make (Config : Config_sig.SERVICE) (Log : Log_sig.SERVICE) :
  Data_db_sig.SERVICE = struct
  let create_pool () =
    match !pool_ref with
    | Some pool ->
        Log.debug (fun m ->
            m "DB: Skipping pool creation, re-using existing pool");
        pool
    | None -> (
        let pool_size = Config.read_int ~default:10 "DATABASE_POOL_SIZE" in
        Log.debug (fun m -> m "DB: Create pool with size %i" pool_size);
        "DATABASE_URL" |> Config.read_string |> Uri.of_string
        |> Caqti_lwt.connect_pool ~max_size:pool_size
        |> function
        | Ok pool ->
            pool_ref := Some pool;
            pool
        | Error err ->
            let msg = "DB: Failed to connect to DB pool" in
            Log.err (fun m -> m "%s %s" msg (Caqti_error.show err));
            raise (Exception ("DB: Failed to create pool " ^ msg)) )

  let ctx_with_pool () =
    let pool = create_pool () in
    Core_ctx.(empty |> ctx_add_pool pool)

  let add_pool ctx =
    let pool = create_pool () in
    ctx_add_pool pool ctx

  let lifecycle =
    Core.Container.Lifecycle.make "db" ~dependencies:[ Config.lifecycle ]
      (fun ctx -> ctx |> add_pool |> Lwt.return)
      (fun _ -> Lwt.return ())

  let query ctx f =
    match
      (Core_ctx.find ctx_key_connection ctx, Core_ctx.find ctx_key_pool ctx)
    with
    | Some connection, _ -> (
        let* result = Lwt.catch (fun () -> f connection) (fun e -> raise e) in
        match result with
        | Ok result -> Lwt.return result
        | Error error ->
            let msg = Caqti_error.show error in
            Log.err (fun m -> m "DB: %s" msg);
            raise (Exception msg) )
    | None, Some pool -> (
        let* result =
          Lwt.catch (fun () -> Caqti_lwt.Pool.use f pool) (fun e -> raise e)
        in
        match result with
        | Ok result -> Lwt.return result
        | Error error ->
            let msg = Caqti_error.show error in
            Log.err (fun m -> m "DB: %s" msg);
            raise (Exception msg) )
    | None, None ->
        Log.err (fun m -> m "DB: No connection pool found");
        Log.info (fun m -> m "DB: Have you applied the DB middleware?");
        raise (Exception "No connection pool found")

  let atomic ctx f =
    match Core_ctx.find ctx_key_pool ctx with
    | Some pool -> (
        let n_connections = Caqti_lwt.Pool.size pool in
        let max_connections =
          Config.read_int ~default:10 "DATABASE_POOL_SIZE"
        in
        Log.debug (fun m ->
            m "DB: Pool usage: %i/%i" n_connections max_connections);
        Log.debug (fun m -> m "DB TX: Fetched connection pool from context");
        let* pool_result =
          Caqti_lwt.Pool.use
            (fun connection ->
              Log.debug (fun m -> m "DB TX: Fetched connection from pool");
              let (module Connection : Caqti_lwt.CONNECTION) = connection in
              let* start_result = Connection.start () in
              match start_result with
              | Error msg ->
                  Log.debug (fun m ->
                      m "DB TX: Failed to start transaction %s"
                        (Caqti_error.show msg));
                  Lwt.return @@ Error msg
              | Ok () ->
                  Log.debug (fun m -> m "DB TX: Started transaction");
                  let ctx_with_connection =
                    Core_ctx.add ctx_key_connection (module Connection) ctx
                  in
                  Lwt.catch
                    (fun () ->
                      let* result = f ctx_with_connection in
                      let* commit_result = Connection.commit () in
                      match commit_result with
                      | Ok () ->
                          Log.debug (fun m ->
                              m "DB TX: Successfully committed transaction");
                          Lwt.return (Ok result)
                      | Error error ->
                          Log.err (fun m ->
                              m "DB TX: Failed to commit transaction %s"
                                (Caqti_error.show error));
                          raise @@ Exception "Failed to commit transaction")
                    (fun e ->
                      let* rollback_result = Connection.rollback () in
                      match rollback_result with
                      | Ok () ->
                          Log.debug (fun m ->
                              m "DB TX: Successfully rolled back transaction");
                          raise e
                      | Error error ->
                          Log.err (fun m ->
                              m "DB TX: Failed to rollback transaction %s"
                                (Caqti_error.show error));
                          raise @@ Exception "Failed to rollback transaction"))
            pool
        in
        match pool_result with
        | Ok result ->
            (* All good, return result of f ctx *)
            Lwt.return result
        | Error pool_err ->
            (* Failed to start, commit or rollback transaction *)
            raise (Exception (pool_err |> Caqti_error.show)) )
    | None ->
        Log.err (fun m -> m "No connection pool found");
        Log.info (fun m -> m "Have you applied the DB middleware?");
        raise (Exception "No connection pool found")

  let single_connection ctx f =
    match Core_ctx.find ctx_key_pool ctx with
    | Some pool -> (
        let n_connections = Caqti_lwt.Pool.size pool in
        let max_connections =
          Config.read_int ~default:10 "DATABASE_POOL_SIZE"
        in
        Log.debug (fun m ->
            m "DB: Pool usage: %i/%i" n_connections max_connections);
        let* pool_result =
          Caqti_lwt.Pool.use
            (fun connection ->
              Log.debug (fun m -> m "DB: Fetched connection pool from context");
              let (module Connection : Caqti_lwt.CONNECTION) = connection in
              let ctx_with_connection =
                Core_ctx.add ctx_key_connection (module Connection) ctx
              in
              f ctx_with_connection |> Lwt.map Result.return)
            pool
        in
        Log.debug (fun m -> m "DB: Putting back connection to pool");
        match pool_result with
        | Ok result ->
            (* All good, return result of f ctx *)
            Lwt.return result
        | Error pool_err ->
            (* Failed to start, commit or rollback transaction *)
            raise (Exception (pool_err |> Caqti_error.show)) )
    | None ->
        Log.err (fun m -> m "No connection pool found");
        Log.info (fun m -> m "Have you applied the DB middleware?");
        raise (Exception "No connection pool found")

  let set_fk_check_request =
    Caqti_request.exec Caqti_type.bool "SET FOREIGN_KEY_CHECKS = ?;"

  let set_fk_check ctx ~check =
    query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec set_fk_check_request check)
end
