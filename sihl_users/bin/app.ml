open Opium.Std
open Lwt

let log_level = Some Logs.Debug

let _ = Printf.sprintf "%s hey" "what"

let set_logger () =
  Lwt.return (Logs_fmt.reporter () |> Logs.set_reporter) >|= fun () ->
  Logs.set_level log_level

let run (app : unit Lwt.t) =
  Lwt_main.run
    ( set_logger () >>= fun () ->
      Logs_lwt.info (fun m -> m "Running...") >>= fun () -> app )

let () =
  match App.run_command' Sihl_users.App.app with
  | `Ok (app : unit Lwt.t) -> run app
  | `Error -> exit 1
  | `Not_running -> exit 0
