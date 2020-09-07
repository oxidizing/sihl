open Base
open Lwt.Syntax
open Data_db_core
module Sig = Data_db_service_sig

module Make
    (Config : Configuration.Service.Sig.SERVICE)
    (Log : Log.Service.Sig.SERVICE) : Sig.SERVICE = struct
  let print_pool_usage pool =
    let n_connections = Caqti_lwt.Pool.size pool in
    let max_connections = Config.read_int ~default:10 "DATABASE_POOL_SIZE" in
    Log.debug (fun m -> m "DB: Pool usage: %i/%i" n_connections max_connections)

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
    Core.Ctx.(empty |> ctx_add_pool pool)

  let add_pool ctx =
    let pool = create_pool () in
    ctx_add_pool pool ctx

  let lifecycle =
    Core.Container.Lifecycle.make "db"
      ~dependencies:[ Config.lifecycle; Log.lifecycle ]
      (fun ctx -> ctx |> add_pool |> Lwt.return)
      (fun _ -> Lwt.return ())

  let query ctx f =
    match
      (Core.Ctx.find ctx_key_connection ctx, Core.Ctx.find ctx_key_pool ctx)
    with
    | Some connection, None -> (
        let* result = f connection in
        match result with
        | Ok result -> Lwt.return result
        | Error error ->
            let msg = Caqti_error.show error in
            Log.err (fun m -> m "DB: %s" msg);
            Lwt.fail (Exception msg) )
    | None, Some pool -> (
        print_pool_usage pool;
        let* result = Caqti_lwt.Pool.use f pool in
        match result with
        | Ok result -> Lwt.return result
        | Error error ->
            let msg = Caqti_error.show error in
            Log.err (fun m -> m "DB: %s" msg);
            Lwt.fail (Exception msg) )
    | Some _, Some _ ->
        Log.err (fun m ->
            m
              "DB: Connection AND pool found in context, this should never \
               happen and might indicate connection leaks. Please report this \
               issue.");
        Lwt.fail (Exception "Connection and pool found")
    | None, None ->
        Log.err (fun m -> m "DB: No connection pool found");
        Log.info (fun m -> m "DB: Have you applied the DB middleware?");
        Lwt.fail (Exception "No connection pool found")

  let with_connection ctx f =
    match Core.Ctx.find ctx_key_pool ctx with
    | Some pool -> (
        print_pool_usage pool;
        let* pool_result =
          Caqti_lwt.Pool.use
            (fun connection ->
              Log.debug (fun m -> m "DB TX: Fetched connection from pool");
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
        match pool_result with
        | Ok result ->
            (* All good, return result of f ctx *)
            Lwt.return result
        | Error pool_err ->
            (* Failed to start, commit or rollback transaction *)
            Lwt.fail (Exception (pool_err |> Caqti_error.show)) )
    | None ->
        Log.err (fun m -> m "No connection pool found");
        Log.info (fun m -> m "Have you applied the DB middleware?");
        Lwt.fail (Exception "No connection pool found")

  let atomic ctx f =
    match Core.Ctx.find ctx_key_pool ctx with
    | Some pool -> (
        print_pool_usage pool;
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
                  (* Remove the pool so that all subsequent queries are executed on the connection. A transaction can only be done only at one connection, it can not span multiple connections. *)
                  let ctx_with_connection =
                    ctx |> remove_pool |> add_connection (module Connection)
                  in
                  Lwt.catch
                    (fun () ->
                      let* result = f ctx_with_connection in
                      let* commit_result = Connection.commit () in
                      match commit_result with
                      | Ok () ->
                          Log.debug (fun m ->
                              m "DB TX: Successfully committed transaction");
                          Lwt.return @@ Ok result
                      | Error error ->
                          Log.err (fun m ->
                              m "DB TX: Failed to commit transaction %s"
                                (Caqti_error.show error));
                          Lwt.fail @@ Exception "Failed to commit transaction")
                    (fun e ->
                      let* rollback_result = Connection.rollback () in
                      match rollback_result with
                      | Ok () ->
                          Log.debug (fun m ->
                              m "DB TX: Successfully rolled back transaction");
                          Lwt.fail e
                      | Error error ->
                          Log.err (fun m ->
                              m "DB TX: Failed to rollback transaction %s"
                                (Caqti_error.show error));
                          Lwt.fail @@ Exception "Failed to rollback transaction"))
            pool
        in
        match pool_result with
        | Ok result ->
            (* All good, return result of f ctx *)
            Lwt.return result
        | Error pool_err ->
            (* Failed to start, commit or rollback transaction *)
            Lwt.fail (Exception (pool_err |> Caqti_error.show)) )
    | None ->
        Log.err (fun m -> m "No connection pool found");
        Log.info (fun m -> m "Have you applied the DB middleware?");
        Lwt.fail (Exception "No connection pool found")

  let set_fk_check_request =
    Caqti_request.exec Caqti_type.bool "SET FOREIGN_KEY_CHECKS = ?;"

  let set_fk_check ctx ~check =
    query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec set_fk_check_request check)

  let with_disabled_fk_check ctx f =
    with_connection ctx (fun ctx ->
        let* () = set_fk_check ctx ~check:false in
        Lwt.finalize (fun () -> f ctx) (fun () -> set_fk_check ctx ~check:true))
end
