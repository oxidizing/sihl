let ( let* ) = Lwt.bind

let ctx_token_key : Token.t Core.Ctx.key = Core.Ctx.create_key ()

module Make
    (MessageService : Message.Sig.Service)
    (TokenService : Token.Sig.SERVICE)
    (LogService : Log.Sig.SERVICE) =
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
        | Error msg ->
            LogService.err (fun m ->
                m "MIDDLEWARE: Failed to retrieve CSRF token. %s" msg);
            MessageService.set ctx
              ~error:[ "MIDDLEWARE: Failed to retrieve CSRF token" ]
              ()
      in
      let* token = TokenService.create ctx ~kind:"csrf" () in
      let ctx =
        match token with
        | Ok token -> Core_ctx.add ctx_token_key token ctx
        | Error msg ->
            LogService.err (fun m ->
                m "MIDDLEWARE: Could not create CSRF token. %s" msg);
            failwith "MIDDLEWARE: Could not create CSRF token."
      in
      handler ctx
    in
    Web_middleware_core.create ~name:"csrf" filter
end
