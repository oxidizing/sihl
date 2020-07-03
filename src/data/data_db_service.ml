module Service : Data_db_sig.SERVICE = struct
  let on_bind _ = Lwt_result.return ()

  let on_start _ = Lwt_result.return ()

  let on_stop _ = Lwt_result.return ()

  let add_pool _ = failwith "TODO register_config"
end

let instance =
  Core.Container.create_binding Data_db_sig.key (module Service) (module Service)
