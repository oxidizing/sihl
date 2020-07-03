module Service : Web_server_sig.SERVICE = struct
  let on_bind _ = Lwt_result.return ()

  let on_start _ = Lwt_result.return ()

  let on_stop _ = Lwt_result.return ()

  let register_routes _ _ = failwith "TODO register_routes"
end

let instance =
  Core.Container.create_binding Web_server_sig.key
    (module Service)
    (module Service)
