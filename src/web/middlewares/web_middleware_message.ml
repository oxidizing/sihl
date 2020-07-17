let ( let* ) = Lwt.bind

module Make (MessageService : Message.Sig.Service) = struct
  let m () =
    let filter handler ctx =
      let* result = MessageService.rotate ctx in
      match result with
      | Ok (Some message) ->
          let ctx = Message.ctx_add message ctx in
          handler ctx
      | Ok None -> handler ctx
      | Error msg ->
          Logs.err (fun m -> m "MIDDLEWARE: Can not rotate messages %s" msg);
          handler ctx
    in
    Web_middleware_core.create ~name:"message" filter
end
