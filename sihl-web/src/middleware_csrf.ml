open Lwt.Syntax
module Core = Sihl_core
module Token = Sihl_type.Token
module Session = Sihl_type.Session

let log_src = Logs.Src.create "sihl.middleware.csrf"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let key : string Opium.Context.key =
  Opium.Context.Key.create ("csrf token", Sexplib.Std.sexp_of_string)
;;

exception Crypto_failed of string
exception Csrf_token_not_found

(* Can be used to fetch token in view for forms *)
let find req =
  try Opium.Context.find_exn key req.Opium.Request.env with
  | _ ->
    Logs.err (fun m -> m "No CSRF token found");
    Logs.info (fun m -> m "Have you applied the CSRF middleware for this route?");
    raise @@ Csrf_token_not_found
;;

let find_opt req =
  try Some (find req) with
  | _ -> None
;;

let set token req =
  let env = req.Opium.Request.env in
  let env = Opium.Context.add key token env in
  { req with env }
;;

(* TODO (https://docs.djangoproject.com/en/3.0/ref/csrf/#how-it-works) Check other Django
   specifics namely:
 * Testing views with custom HTTP client
 * Allow Sihl user to make views exempt
 * Enable subdomain
 * HTML caching token handling
 *)
module Make
    (TokenService : Sihl_contract.Token.Sig)
    (SessionService : Sihl_contract.Session.Sig) =
struct
  let create_secret session =
    let* token = TokenService.create ~kind:"csrf" ~length:20 () in
    (* Store the ID in the session *)
    (* Storing the token directly could mean it ends up on the client if the cookie
       backend is used for session storage *)
    let* () = SessionService.set_value session ~k:"csrf" ~v:(Some token.id) in
    Lwt.return token
  ;;

  let secret_to_token secret =
    (* Randomize and scramble secret (XOR with salt) to make a token *)
    (* Do this to mitigate BREACH attacks: http://breachattack.com/#mitigations *)
    let secret_length = String.length (Token.value secret) in
    let salt = Core.Random.bytes ~nr:secret_length in
    let secret_value = Token.value secret |> String.to_seq |> List.of_seq in
    let encrypted =
      match Sihl_core.Utils.Encryption.xor salt secret_value with
      | None ->
        Logs.err (fun m -> m "Failed to encrypt CSRF secret");
        raise @@ Crypto_failed "Failed to encrypt CSRF secret"
      | Some enc -> enc
    in
    encrypted
    |> List.append salt
    |> List.to_seq
    |> String.of_seq
    (* Make the token transmittable without encoding problems *)
    |> Base64.encode_string ~alphabet:Base64.uri_safe_alphabet
  ;;

  let m ?not_allowed_handler () =
    let filter handler req =
      (* Check if session already has a secret (token) *)
      let session = Middleware_session.find req in
      let* id = SessionService.find_value session "csrf" in
      let* secret =
        match id with
        (* Create a secret if no secret found in session *)
        | None ->
          Logs.debug (fun m -> m "CSRF token in session not found, create new token");
          create_secret session
        | Some token_id ->
          let* token = TokenService.find_by_id_opt token_id in
          (match token with
          (* Create a secret if invalid token in session *)
          | None ->
            Logs.debug (fun m ->
                m "CSRF token in session is invalid or does not exist, create new one");
            create_secret session
          (* Return valid secret from session *)
          | Some secret ->
            Logs.debug (fun m -> m "Fetch valid token from session");
            Lwt.return secret)
      in
      let token = secret_to_token secret in
      let req = set token req in
      (* Don't check for CSRF token in GET requests *)
      let is_safe =
        match req.Opium.Request.meth with
        | `GET | `HEAD | `OPTIONS | `TRACE -> true
        | _ -> false
      in
      if is_safe
      then handler req
      else (
        let req, value = Middleware_urlencoded.consume req "csrf" in
        match value with
        (* Give 403 if no token provided *)
        | None ->
          (match not_allowed_handler with
          | Some handler -> Lwt.return @@ handler req
          | None -> Opium.Response.(of_plain_text ~status:`Forbidden "") |> Lwt.return)
        | Some value ->
          let decoded = Base64.decode ~alphabet:Base64.uri_safe_alphabet value in
          let decoded =
            match decoded with
            | Ok decoded -> decoded
            | Error (`Msg msg) ->
              Logs.err (fun m -> m "Failed to decode CSRF token. %s" msg);
              raise @@ Crypto_failed ("Failed to decode CSRF token. " ^ msg)
          in
          let salted_cipher = decoded |> String.to_seq |> List.of_seq in
          let decrypted_secret =
            match
              Sihl_core.Utils.Encryption.decrypt_with_salt
                ~salted_cipher
                ~salt_length:(List.length salted_cipher / 2)
            with
            | None ->
              Logs.err (fun m -> m "Failed to decrypt CSRF token %s " token);
              raise @@ Crypto_failed "Failed to decrypt CSRF token"
            | Some dec -> dec
          in
          let* provided_secret =
            TokenService.find_opt (decrypted_secret |> List.to_seq |> String.of_seq)
          in
          (match provided_secret with
          | Some ps ->
            if not @@ Token.equal secret ps
            then (
              Logs.err (fun m ->
                  m "Associated CSRF token does not match with provided token");
              match not_allowed_handler with
              | None ->
                (* Give 403 if provided secret doesn't match session secret *)
                Opium.Response.(of_plain_text ~status:`Forbidden "") |> Lwt.return
              | Some handler -> Lwt.return @@ handler req)
            else
              (* Provided secret matches and is valid => Invalidate it so it can't be
                 reused *)
              let* () = TokenService.invalidate ps in
              (* To allow fetching a new valid token from the context, generate a new one *)
              let* secret = create_secret session in
              let token = secret_to_token secret in
              let req = set token req in
              handler req
          | None ->
            Logs.err (fun m -> m "No token associated with CSRF token");
            (match not_allowed_handler with
            | None ->
              (* Give 403 if provided secret does not exist *)
              Opium.Response.(of_plain_text ~status:`Forbidden "") |> Lwt.return
            | Some handler -> Lwt.return @@ handler req)))
    in
    Rock.Middleware.create ~name:"csrf" ~filter
  ;;
end
