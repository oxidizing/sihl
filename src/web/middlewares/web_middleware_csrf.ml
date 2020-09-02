open Lwt.Syntax

let ctx_token_key : Token.t Core.Ctx.key = Core.Ctx.create_key ()

(*TODO [aerben] optional*)
let get_token ctx = Core_ctx.find ctx_token_key ctx

exception No_csrf_token of string

(* TODO [aerben] rebase *)
(* TODO [aerben] salt token *)
(* TODO [aerben] remove unit for non-optional fns *)
(* TODO [aerben] use sessionservice, see if already has unexpired token, if yes, just create new salt, if no, create new token and new salt, maybe see if sessions expire too, then dont need token expiry, salting and hashing has to be fast! *)
(* TODO (https://docs.djangoproject.com/en/3.0/ref/csrf/#how-it-works)
Check other Django specifics namely:
   - Testing views with custom HTTP client
   - Allow Sihl user to make views exempt
   - Enable subdomain
   - HTML caching token handling
*)
module Make
    (TokenService : Token.Sig.SERVICE)
    (Log : Log.Sig.SERVICE)
    (SessionService : Session.Sig.SERVICE) =
struct
  let m () =
    let filter handler ctx =
      (* Create a token no matter the HTTP request type *)
      let* token = TokenService.create ctx ~kind:"csrf" () in
      (* Store the ID in the session *)
      (* Storing the token directly could mean it ends up on the client
         if the cookie backend is used for session storage *)
      let* () = SessionService.set_value ctx ~key:"csrf" ~value:token.id in
      let ctx = Core_ctx.add ctx_token_key token ctx in
      (* Don't check for CSRF token in GET requests *)
      (* TODO don't check for HEAD, OPTIONS and TRACE either *)
      if Web_req.is_get ctx then handler ctx
      else
        let* value = Web_req.urlencoded ctx "csrf" in
        match value with
        (* Give 403 if no token provided *)
        | Error _ -> Web_res.(html |> set_status 403) |> Lwt.return
        | Ok value -> (
            let* id = SessionService.get_value ctx ~key:"csrf" in
            let token_id =
              match id with
              | None ->
                  (* TODO [aerben] SHOULD THIS BE 403? *)
                  Log.err (fun m ->
                      m "MIDDLEWARE: No CSRF token found in session %s."
                        (SessionService.require_session_key ctx));
                  raise @@ No_csrf_token "No CSRF token found in session"
              | Some token_id -> token_id
            in
            let* session_token =
              TokenService.find_by_id_opt ctx ~id:token_id ()
            in
            let* provided_token = TokenService.find_opt ctx ~value () in
            match (session_token, provided_token) with
            | Some tks, Some tkp ->
                if Bool.not @@ Token.equal tks tkp then
                  (* Give 403 if provided token doesn't match session token *)
                  Web_res.(html |> set_status 403) |> Lwt.return
                else
                  (* Provided token matches and is valid => Invalidate it so it can't be reused *)
                  let* () = TokenService.invalidate ctx ~token:tkp () in
                  handler ctx
            | _, None ->
                (* Give 403 if provided token is not an existing token  *)
                Web_res.(html |> set_status 403) |> Lwt.return
            | None, _ ->
                (* Token is in session but does not exist, something has gone wrong *)
                Log.err (fun m ->
                    m "MIDDLEWARE: CSRF token from session does not exist");
                raise @@ No_csrf_token "CSRF token from session does not exist"
            )
    in

    Web_middleware_core.create ~name:"csrf" filter
end
