module Service : Config_sig.SERVICE = struct
  let on_bind _ = Lwt_result.return ()

  let on_start _ = Lwt_result.return ()

  let on_stop _ = Lwt_result.return ()

  let register_config _ _ = failwith "TODO register_config"
end

let instance =
  Core.Container.create_binding Config_sig.key (module Service) (module Service)
