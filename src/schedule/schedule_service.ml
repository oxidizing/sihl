let on_init _ = Lwt_result.return ()

let on_start _ = Lwt_result.return ()

let on_stop _ = Lwt_result.return ()

let register_schedules _ _ =
  Logs.warn (fun m ->
      m "SCHEDULE: Registration of schedules is not implemented");
  Lwt_result.return ()
