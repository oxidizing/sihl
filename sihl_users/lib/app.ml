open Core
open Opium.Std
open Lwt

let static = Middleware.static ~local_path:"./static" ~uri_prefix:"/static" ()

let app : Opium.App.t =
  App.empty
  |> App.cmd_name "User Management"
  (* TODO setup core middlewares in core, hidden from user *)
  |> Sihl_core.Http.Middleware.handle_error
  |> middleware static |> Sihl_core.Db.middleware
  |> middleware Service.Middleware.Authentication.m
  |> Handler.add_handlers

let log_level = Some Logs.Debug

let set_logger () =
  Lwt.return (Logs_fmt.reporter () |> Logs.set_reporter) >|= fun () ->
  Logs.set_level log_level

let run (app : unit Lwt.t) =
  let _ = set_logger () in
  let _ = Logs_lwt.info (fun m -> m "Running...") in
  app

let start () =
  match App.run_command' app with
  | `Ok (app : unit Lwt.t) -> run app
  | `Error -> exit 1
  | `Not_running -> exit 0

let clean () =
  Sihl_core.Db.clean [ Repository.Token.clean; Repository.User.clean ]
  >|= Result.ok_or_failwith
