let ( let* ) = Lwt.bind

let m () =
  let filter handler ctx =
    let* result = Message.rotate ctx in
    match result with
    | Ok () -> handler ctx
    | Error msg ->
        Logs.err (fun m -> m "MIDDLEWARE: Can not rotate messages %s" msg);
        handler ctx
  in
  Web_middleware_core.create ~name:"message" filter
