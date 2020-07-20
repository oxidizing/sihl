open Base
include Logs

let get_level () =
  let level = Sys.getenv "LOG_LEVEL" |> Option.map ~f:String.lowercase in
  match level with
  | Some "info" -> Info
  | Some "debug" -> Debug
  | Some "warning" -> Warning
  | Some "error" -> Error
  | _ -> Warning

let on_init _ =
  let log_level = Some (get_level ()) in
  Logs_fmt.reporter () |> set_reporter;
  set_level log_level;
  debug (fun m -> m "LOGGER: Logger set up");
  Lwt_result.return ()

let on_start _ = Lwt_result.return ()

let on_stop _ = Lwt_result.return ()
