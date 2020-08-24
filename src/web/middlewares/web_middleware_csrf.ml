open Lwt.Syntax

let ctx_token_key : Token.t Core.Ctx.key = Core.Ctx.create_key ()

(*TODO [aerben] optional*)
let get_token ctx = Core_ctx.find ctx_token_key ctx

exception Invalid_csrf_token of string

(* TODO [aerben] rebase *)
(* TODO [aerben] salt token *)
(* TODO [aerben] remove unit for non-optional fns *)
(* TODO [aerben] use sessionservice, see if already has unexpired token, if yes, just create new salt, if no, create new token and new salt, maybe see if sessions expire too, then dont need token expiry, salting and hashing has to be fast! *)
(* TODO [aerben] (https://docs.djangoproject.com/en/3.0/ref/csrf/#how-it-works)
Check other Django specifics namely:
   - No tokens for HEAD, OPTIONS or TRACE
   - Testing views with custom HTTP client
   - Allow Sihl user to make views exempt
   - Enable subdomain
   - HTML caching token handling
*)
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
