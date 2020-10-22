open Lwt.Syntax

(* Can be used to fetch token in view for forms *)
let ctx_token_key : string Core.Ctx.key = Core.Ctx.create_key ()
let get_token ctx = Core.Ctx.find ctx_token_key ctx

exception Crypto_failed of string

(* TODO (https://docs.djangoproject.com/en/3.0/ref/csrf/#how-it-works) Check other Django
   specifics namely:
 * Testing views with custom HTTP client
 * Allow Sihl user to make views exempt
 * Enable subdomain
 * HTML caching token handling
 *)
module Make
    (TokenService : Token.Sig.SERVICE)
    (SessionService : Session.Sig.SERVICE)
    (RandomService : Random.Sig.SERVICE) =
struct
  let create_secret ctx =
    let* token = TokenService.create ctx ~kind:"csrf" ~length:20 () in
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
      let secret_length = String.length secret.value in
      let salt = RandomService.bytes ~nr:secret_length in
      let secret_value = Utils.String.string_to_char_list secret.value in
      let encrypted =
        match Utils.Encryption.xor salt secret_value with
        | None ->
          Logs.err (fun m -> m "MIDDLEWARE: Failed to encrypt CSRF secret");
          raise @@ Crypto_failed "Failed to encrypt CSRF secret"
        | Some enc -> enc
      in
      let token =
        encrypted
        |> List.append salt
        |> Utils.String.char_list_to_string
        (* Make the token transmittable without encoding problems *)
        |> Base64.encode_string ~alphabet:Base64.uri_safe_alphabet
      in
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
          let decoded = Base64.decode ~alphabet:Base64.uri_safe_alphabet value in
          let decoded =
            match decoded with
            | Ok decoded -> decoded
            | Error (`Msg msg) ->
              Logs.err (fun m -> m "MIDDLEWARE: Failed to decode CSRF token. %s" msg);
              raise @@ Crypto_failed ("Failed to decode CSRF token. " ^ msg)
          in
          let salted_cipher = Utils.String.string_to_char_list decoded in
          let decrypted_secret =
            match
              Utils.Encryption.decrypt_with_salt
                ~salted_cipher
                ~salt_length:(List.length salted_cipher / 2)
            with
            | None ->
              Logs.err (fun m -> m "MIDDLEWARE: Failed to decrypt CSRF token");
              raise @@ Crypto_failed "Failed to decrypt CSRF token"
            | Some dec -> dec
          in
          let* provided_secret =
            TokenService.find_opt ctx (Utils.String.char_list_to_string decrypted_secret)
          in
          (match provided_secret with
          | Some ps ->
            if not @@ Token.equal secret ps
            then
              (* Give 403 if provided secret doesn't match session secret *)
              Http.Res.(html |> set_status 403) |> Lwt.return
            else
              (* Provided secret matches and is valid => Invalidate it so it can't be
                 reused *)
              let* () = TokenService.invalidate ctx ps in
              handler ctx
          | None ->
            (* Give 403 if provided secret does not exist *)
            Http.Res.(html |> set_status 403) |> Lwt.return)
    in
    Middleware_core.create ~name:"csrf" filter
  ;;
end
