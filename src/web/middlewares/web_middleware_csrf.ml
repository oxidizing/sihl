let ( let* ) = Lwt.bind

module CsrfService = struct
  let add_to_ctx ctx ~token () =
    let open Core_ctx in
    let key : Token.t key = create_key () in
    add key token ctx
end

module Make
    (MessageService : Message.Sig.Service)
    (TokenService : Token.Sig.SERVICE) =
struct
  let m () =
    let filter handler ctx =
      let open Lwt_result.Infix in
      let* res =
        Web_req.urlencoded ctx "csrf" >>= fun value ->
        TokenService.find ctx ~value ()
      in
      let _ =
        match res with
        | Ok token -> TokenService.invalidate ctx ~token ()
        | Error _ ->
            Logs.err (fun m -> m "MIDDLEWARE: Failed to retrieve CSRF token");
            MessageService.set ctx ~error:[ "TODO ERROR MESSAGE" ] ()
      in
      let* token = TokenService.create ctx ~kind:"csrf" () in
      let ctx =
        match token with
        | Ok token -> CsrfService.add_to_ctx ctx ~token ()
        | Error msg ->
            Logs.err (fun m -> m "MIDDLEWARE: Could not create token %s" msg);
            ctx
      in
      handler ctx
    in
    Web_middleware_core.create ~name:"csrf" filter
end
