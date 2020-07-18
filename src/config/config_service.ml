let on_init _ = Lwt_result.return ()

let on_start _ = Lwt_result.return ()

let on_stop _ = Lwt_result.return ()

let register_config _ config =
  Logs.debug (fun m -> m "CONFIG: Register config");
  Config_core.Internal.register config |> Lwt.return
