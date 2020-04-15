open Opium.Std
open Lwt
open Sihl_core

let static = Middleware.static ~local_path:"./static" ~uri_prefix:"/static" ()

(** Build the Opium app  *)
let app : Opium.App.t =
  App.empty
  |> App.cmd_name "Ocaml Webapp Tutorial"
  |> middleware static |> Db.middleware |> Route.add_routes

let log_level = Some Logs.Debug

(** Configure the logger *)
let set_logger () =
  (* Adapted from  https://github.com/rgrinberg/opium/blob/master/examples/hello_world_log.ml#L4 *)
  Lwt.return (Logs_fmt.reporter () |> Logs.set_reporter) >|= fun () ->
  Logs.set_level log_level

(** Sequence the app execution *)
let run (app : unit Lwt.t) =
  Lwt_main.run
    ( set_logger () >>= fun () ->
      (* set logger *)
      Logs_lwt.info (fun m -> m "Running...") >>= fun () ->
      (* log a message *)
      app (* run the app *) )

(** Run the application *)
let () =
  (* run_command' generates a CLI that configures a deferred run of the app *)
  match App.run_command' app with
  (* The deferred unit signals the deferred execution of the app *)
  | `Ok (app : unit Lwt.t) -> run app
  | `Error -> exit 1
  | `Not_running -> exit 0
