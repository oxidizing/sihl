open Lwt.Syntax
open Model
module Core = Sihl_core

exception Exception of string

let log_src = Logs.Src.create ~doc:"database" "sihl.service.database"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let pool_ref : pool option ref = ref None

type config =
  { url : string
  ; pool_size : int option
  }

let config url pool_size = { url; pool_size }

let schema =
  let open Conformist in
  make [ string "DATABASE_URL"; optional (int "DATABASE_POOL_SIZE") ] config
;;

let print_pool_usage pool =
  let n_connections = Caqti_lwt.Pool.size pool in
  let max_connections =
    Option.value (Core.Configuration.read_int "DATABASE_POOL_SIZE") ~default:10
  in
  Logs.debug (fun m -> m "Pool usage: %i/%i" n_connections max_connections)
;;

let fetch_pool () =
  match !pool_ref with
  | Some pool ->
    Logs.debug (fun m -> m "Skipping pool creation, re-using existing pool");
    pool
  | None ->
    let pool_size =
      Option.value (Core.Configuration.read_int "DATABASE_POOL_SIZE") ~default:10
    in
    Logs.debug (fun m -> m "Create pool with size %i" pool_size);
    Option.get ("DATABASE_URL" |> Core.Configuration.read_string)
    |> Uri.of_string
    |> Caqti_lwt.connect_pool ~max_size:pool_size
    |> (function
    | Ok pool ->
      pool_ref := Some pool;
      pool
    | Error err ->
      let msg = "Failed to connect to DB pool" in
      Logs.err (fun m -> m "%s %s" msg (Caqti_error.show err));
      raise (Exception ("Failed to create pool " ^ msg)))
;;

let transaction _ f =
  let pool = fetch_pool () in
  print_pool_usage pool;
  let* result =
    Caqti_lwt.Pool.use
      (fun connection ->
        Logs.debug (fun m -> m "Fetched connection from pool");
        let (module Connection : Caqti_lwt.CONNECTION) = connection in
        let* start_result = Connection.start () in
        match start_result with
        | Error msg ->
          Logs.debug (fun m -> m "Failed to start transaction %s" (Caqti_error.show msg));
          Lwt.return @@ Error msg
        | Ok () ->
          Logs.debug (fun m -> m "Started transaction");
          Lwt.catch
            (fun () ->
              let* result = f connection in
              let* commit_result = Connection.commit () in
              match commit_result with
              | Ok () ->
                Logs.debug (fun m -> m "Successfully committed transaction");
                Lwt.return @@ Ok result
              | Error error ->
                Logs.err (fun m ->
                    m "Failed to commit transaction %s" (Caqti_error.show error));
                Lwt.fail @@ Exception "Failed to commit transaction")
            (fun e ->
              let* rollback_result = Connection.rollback () in
              match rollback_result with
              | Ok () ->
                Logs.debug (fun m -> m "Successfully rolled back transaction");
                Lwt.fail e
              | Error error ->
                Logs.err (fun m ->
                    m "Failed to rollback transaction %s" (Caqti_error.show error));
                Lwt.fail @@ Exception "Failed to rollback transaction"))
      pool
  in
  match result with
  | Ok result -> Lwt.return result
  | Error error ->
    let msg = Caqti_error.show error in
    Logs.err (fun m -> m "%s" msg);
    Lwt.fail (Exception msg)
;;

let query _ f =
  let pool = fetch_pool () in
  print_pool_usage pool;
  let* result =
    Caqti_lwt.Pool.use (fun connection -> f connection |> Lwt.map Result.ok) pool
  in
  match result with
  | Ok result -> Lwt.return result
  | Error error ->
    let msg = Caqti_error.show error in
    Logs.err (fun m -> m "%s" msg);
    Lwt.fail (Exception msg)
;;

(* Service lifecycle *)

let start ctx =
  (* Make sure that database is online when starting service. *)
  let _ = fetch_pool () in
  Lwt.return ctx
;;

let stop _ = Lwt.return ()
let lifecycle = Core.Container.Lifecycle.create "database" ~start ~stop

let configure configuration =
  let configuration = Core.Configuration.make ~schema configuration in
  Core.Container.Service.create ~configuration lifecycle
;;
