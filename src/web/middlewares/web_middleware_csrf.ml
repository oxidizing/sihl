open Lwt.Syntax

let ctx_token_key : Token.t Core.Ctx.key = Core.Ctx.create_key ()

(*TODO [aerben] optional*)
let get_token ctx = Core_ctx.find ctx_token_key ctx

module Make (TokenService : Token.Sig.SERVICE) (Log : Log.Sig.SERVICE) = struct
  let m () =
    let filter handler ctx =
      let* value = Web_req.urlencoded ctx "csrf" in
      match value with
      | Error _ -> handler ctx
      | Ok value ->
          let* token = TokenService.find_opt ctx ~value () in
          let* () =
            match token with
            | None ->
                Log.err (fun m ->
                    m "MIDDLEWARE: Failed to retrieve CSRF token. %s" value);
                failwith "MIDDLEWARE: Failed to retrieve CSRF token"
            | Some token -> TokenService.invalidate ctx ~token ()
          in
          let* token = TokenService.create ctx ~kind:"csrf" () in
          let ctx = Core_ctx.add ctx_token_key token ctx in
          handler ctx
    in
    Web_middleware_core.create ~name:"csrf" filter
end
