open Lwt.Syntax

(* Can be used to fetch token in view for forms *)
let ctx_token_key : string Core.Ctx.key = Core.Ctx.create_key ()

(*TODO [aerben] optional*)
let get_token ctx = Core.Ctx.find ctx_token_key ctx

exception No_csrf_token of string

(* TODO (https://docs.djangoproject.com/en/3.0/ref/csrf/#how-it-works) Check other Django
   specifics namely: - Testing views with custom HTTP client - Allow Sihl user to make
   views exempt - Enable subdomain - HTML caching token handling *)
module Make
    (TokenService : Token.Sig.SERVICE)
    (SessionService : Session.Sig.SERVICE)
    (RandomService : Utils.Random.Service.Sig.SERVICE) =
struct
  let csrf_token_length = 20

  let create_secret ctx =
    let* token = TokenService.create ctx ~kind:"csrf" ~length:csrf_token_length () in
    (* Store the ID in the session *)
    (* Storing the token directly could mean it ends up on the client if the cookie
       backend is used for session storage *)
    let* () = SessionService.set ctx ~key:"csrf" ~value:token.id in
    Lwt.return token
  ;;

  let m () =
    let filter handler ctx =
      (* Check if session already has a secret (token) *)
      let* id = SessionService.get ctx ~key:"csrf" in
      let* secret =
        match id with
        (* Create a secret if no secret found in session *)
        | None -> create_secret ctx
        | Some token_id ->
          let* token = TokenService.find_by_id_opt ctx token_id in
          (match token with
          (* Create a secret if invalid token in session *)
          | None -> create_secret ctx
          (* Return valid secret from session *)
          | Some secret -> Lwt.return secret)
      in
      (* Randomize and scramble secret (XOR with salt) to make a token *)
      (* Do this to mitigate BREACH attacks: http://breachattack.com/#mitigations *)
      let salt = RandomService.base64 ~bytes:csrf_token_length in
      let token = salt ^ Utils.Encryption.xor salt secret.value in
      let ctx = Core.Ctx.add ctx_token_key token ctx in
      (* Don't check for CSRF token in GET requests *)
      (* TODO don't check for HEAD, OPTIONS and TRACE either *)
      if Http.Req.is_get ctx
      then handler ctx
      else
        let* value = Http.Req.urlencoded ctx "csrf" in
        match value with
        (* Give 403 if no token provided *)
        | None -> Http.Res.(html |> set_status 403) |> Lwt.return
        | Some value ->
          let token =
            Utils.Encryption.decrypt_with_salt
              ~salted_cipher:value
              ~salt_length:csrf_token_length
          in
          let* provided_token = TokenService.find_opt ctx token in
          (match provided_token with
          | Some tkp ->
            if not @@ Token.equal secret tkp
            then
              (* Give 403 if provided token doesn't match session token *)
              Http.Res.(html |> set_status 403) |> Lwt.return
            else
              (* Provided token matches and is valid => Invalidate it so it can't be
                 reused *)
              let* () = TokenService.invalidate ctx tkp in
              handler ctx
          | None ->
            (* Give 403 if provided token does not exist *)
            Http.Res.(html |> set_status 403) |> Lwt.return)
    in
    Middleware_core.create ~name:"csrf" filter
  ;;
end
