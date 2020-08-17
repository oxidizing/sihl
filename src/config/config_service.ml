let lifecycle =
  Core.Container.Lifecycle.make "config"
    (fun ctx -> Lwt.return ctx)
    (fun _ -> Lwt.return ())

let register_config _ config =
  Logs.debug (fun m -> m "CONFIG: Register config");
  Config_core.Internal.register config |> Lwt.return
