open Lwt.Syntax

let ctx_token_key : Token.t Core.Ctx.key = Core.Ctx.create_key ()

(*TODO [aerben] optional*)
let get_token ctx = Core_ctx.find ctx_token_key ctx

exception Invalid_csrf_token of string

module Make (TokenService : Token.Sig.SERVICE) (Log : Log.Sig.SERVICE) = struct
  let m () =
    let filter handler ctx =
      let* token = TokenService.create ctx ~kind:"csrf" () in
      let ctx = Core_ctx.add ctx_token_key token ctx in
      if Web_req.is_get ctx then handler ctx
      else
        let* value = Web_req.urlencoded ctx "csrf" in
        match value with
        | Error _ -> Web_res.(html |> set_status 403) |> Lwt.return
        | Ok value -> (
            let* token = TokenService.find_opt ctx ~value () in
            match token with
            | None ->
                Log.err (fun m -> m "MIDDLEWARE: Invalid CSRF token. %s" value);
                raise @@ Invalid_csrf_token "Invalid CSRF token"
            | Some token ->
                let* () = TokenService.invalidate ctx ~token () in
                handler ctx )
    in

    Web_middleware_core.create ~name:"csrf" filter
end
