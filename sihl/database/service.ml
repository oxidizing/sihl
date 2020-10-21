open Lwt.Syntax
open Model

let ctx_key_pool : pool Core.Ctx.key = Core.Ctx.create_key ()
let find_pool ctx = Core.Ctx.find ctx_key_pool ctx
let add_pool pool ctx = Core.Ctx.add ctx_key_pool pool ctx
let remove_pool ctx = Core.Ctx.remove ctx_key_pool ctx

let print_pool_usage pool =
  let n_connections = Caqti_lwt.Pool.size pool in
  let max_connections =
    Option.value (Core.Configuration.read_int "DATABASE_POOL_SIZE") ~default:10
  in
  Logs.debug (fun m -> m "DB: Pool usage: %i/%i" n_connections max_connections)
;;

let fetch_pool () =
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

let add_pool ctx =
  let pool = fetch_pool () in
  add_pool pool ctx
;;

let fetch_connection pool =
  let* connection =
    Caqti_lwt.Pool.use (fun connection -> Lwt_result.return connection) pool
  in
  match connection with
  | Ok connection -> Lwt.return connection
  | Error msg -> failwith (Caqti_error.show msg)
;;

let query ctx f =
  let pool = fetch_pool () in
  let* connection =
    Core.Ctx.handle_atomic
      ctx
      (fun () -> fetch_connection pool)
      (fun (module Connection : Caqti_lwt.CONNECTION) ->
        let* result = Connection.commit () in
        match result with
        | Ok () -> Lwt.return ()
        | Error msg -> failwith (Caqti_error.show msg))
  in
  match connection with
  | Some connection -> f connection |> Lwt.map Result.get_ok
  | None -> Caqti_lwt.Pool.use f pool |> Lwt.map Result.get_ok
;;

let set_fk_check_request =
  Caqti_request.exec Caqti_type.bool "SET FOREIGN_KEY_CHECKS = ?;"
;;

let set_fk_check ctx ~check =
  query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
      Connection.exec set_fk_check_request check)
;;

let with_disabled_fk_check ctx f =
  Core.Ctx.atomic ctx (fun ctx ->
      let* () = set_fk_check ctx ~check:false in
      Lwt.finalize (fun () -> f ctx) (fun () -> set_fk_check ctx ~check:true))
;;

(* Service lifecycle *)

let start ctx = ctx |> add_pool |> Lwt.return
let stop _ = Lwt.return ()
let lifecycle = Core.Container.Lifecycle.create "db" ~start ~stop

let configure configuration =
  let configuration = Core.Configuration.make configuration in
  Core.Container.Service.create ~configuration lifecycle
;;
