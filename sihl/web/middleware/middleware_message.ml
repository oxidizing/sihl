open Lwt.Syntax

module Make (MessageService : Message.Sig.SERVICE) = struct
  let m () =
    let filter handler ctx =
      let* result = MessageService.rotate ctx in
      match result with
      | Some message ->
        let ctx = Message.ctx_add message ctx in
        handler ctx
      | None -> handler ctx
    in
    Middleware_core.create ~name:"message" filter
  ;;
end
