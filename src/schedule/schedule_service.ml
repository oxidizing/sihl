module Service : Schedule_sig.SERVICE = struct
  let on_bind _ = Lwt_result.return ()

  let on_start _ = Lwt_result.return ()

  let on_stop _ = Lwt_result.return ()

  let register_schedules _ = failwith "TODO register_schedules"
end

let instance =
  Core.Container.create_binding Schedule_sig.key
    (module Service)
    (module Service)
