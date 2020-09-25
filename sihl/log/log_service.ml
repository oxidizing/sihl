open Base
module Sig = Log_service_sig

module Make () : Sig.SERVICE = struct
  include Logs

  let get_level () =
    let level = Sys.getenv "LOG_LEVEL" |> Option.map ~f:String.lowercase in
    match level with
    | Some "info" -> Info
    | Some "debug" -> Debug
    | Some "warning" -> Warning
    | Some "error" -> Error
    | _ -> Warning

  let start ctx =
    let log_level = Some (get_level ()) in
    Logs_fmt.reporter () |> set_reporter;
    set_level log_level;
    debug (fun m -> m "LOGGER: Logger set up");
    Lwt.return ctx

  let stop _ = Lwt.return ()

  let lifecycle = Core.Container.Lifecycle.make "log" ~start ~stop
end
