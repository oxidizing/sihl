module Service = Cmd_service
include Cmd_core

let register_commands _ _ =
  Logs.warn (fun m -> m "CMD: Registration of commands is not implemented");
  Lwt_result.return ()
