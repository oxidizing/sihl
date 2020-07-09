module Service : Log_sig.SERVICE = struct
  include Logs

  let on_bind _ =
    let log_level = Some Warning in
    Logs_fmt.reporter () |> set_reporter;
    set_level log_level;
    debug (fun m -> m "LOGGER: Logger set up");
    Lwt_result.return ()

  let on_start _ = Lwt_result.return ()

  let on_stop _ = Lwt_result.return ()
end

let instance =
  Core.Container.create_binding Log_sig.key (module Service) (module Service)
