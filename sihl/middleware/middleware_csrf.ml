module Core = Sihl_core
module Utils = Sihl_utils
module Http = Sihl_http
module Token = Sihl_token
module Session = Sihl_session
open Lwt.Syntax

let log_src = Logs.Src.create ~doc:"CSRF Middleware" "sihl.middleware.csrf"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let key : string Opium_kernel.Hmap.key =
  Opium_kernel.Hmap.Key.create ("csrf token", Sexplib.Std.sexp_of_string)
;;

exception Crypto_failed of string

(* Can be used to fetch token in view for forms *)
let find req = Opium_kernel.Hmap.find_exn key (Opium_kernel.Request.env req)

let find_opt req =
  try Some (find req) with
  | _ -> None
;;

let set token req =
  let env = Opium_kernel.Request.env req in
  let env = Opium_kernel.Hmap.add key token env in
  { req with env }
;;

(* TODO (https://docs.djangoproject.com/en/3.0/ref/csrf/#how-it-works) Check other Django
   specifics namely:
 * Testing views with custom HTTP client
 * Allow Sihl user to make views exempt
 * Enable subdomain
 * HTML caching token handling
 *)
module Make (TokenService : Token.Sig.SERVICE) (SessionService : Session.Sig.SERVICE) =
struct
  let create_secret ctx session =
    let* token = TokenService.create ctx ~kind:"csrf" ~length:20 () in
    (* Store the ID in the session *)
    (* Storing the token directly could mean it ends up on the client if the cookie
       backend is used for session storage *)
    let* () = SessionService.set ctx session ~key:"csrf" ~value:token.id in
    Lwt.return token
  ;;

  let m () =
    let filter handler req =
      let ctx = Http.Request.to_ctx req in
      (* Check if session already has a secret (token) *)
      let session =
        match Middleware_session.find_opt req with
        | Some session -> session
        | None ->
          Logs.info (fun m -> m "Have you applied the session middleware?");
          raise (Crypto_failed "No session found")
      in
      let* id = SessionService.get ctx session ~key:"csrf" in
      let* secret =
        match id with
        (* Create a secret if no secret found in session *)
        | None -> create_secret ctx session
        | Some token_id ->
          let* token = TokenService.find_by_id_opt ctx token_id in
          (match token with
          (* Create a secret if invalid token in session *)
          | None -> create_secret ctx session
          (* Return valid secret from session *)
          | Some secret -> Lwt.return secret)
      in
      (* Randomize and scramble secret (XOR with salt) to make a token *)
      (* Do this to mitigate BREACH attacks: http://breachattack.com/#mitigations *)
      let secret_length = String.length secret.value in
      let salt = Core.Random.bytes ~nr:secret_length in
      let secret_value = secret.value |> String.to_seq |> List.of_seq in
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
        |> List.to_seq
        |> String.of_seq
        (* Make the token transmittable without encoding problems *)
        |> Base64.encode_string ~alphabet:Base64.uri_safe_alphabet
      in
      let req = set token req in
      (* Don't check for CSRF token in GET requests *)
      (* TODO don't check for HEAD, OPTIONS and TRACE either *)
      if Http.Request.is_get req
      then handler req
      else
        let* value = Http.Request.urlencoded "csrf" req in
        match value with
        (* Give 403 if no token provided *)
        | None -> Http.Response.(create () |> set_status 403) |> Lwt.return
        | Some value ->
          let decoded = Base64.decode ~alphabet:Base64.uri_safe_alphabet value in
          let decoded =
            match decoded with
            | Ok decoded -> decoded
            | Error (`Msg msg) ->
              Logs.err (fun m -> m "MIDDLEWARE: Failed to decode CSRF token. %s" msg);
              raise @@ Crypto_failed ("Failed to decode CSRF token. " ^ msg)
          in
          let salted_cipher = decoded |> String.to_seq |> List.of_seq in
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
            TokenService.find_opt ctx (decrypted_secret |> List.to_seq |> String.of_seq)
          in
          (match provided_secret with
          | Some ps ->
            if not @@ Token.equal secret ps
            then
              (* Give 403 if provided secret doesn't match session secret *)
              Http.Response.(create () |> set_status 403) |> Lwt.return
            else
              (* Provided secret matches and is valid => Invalidate it so it can't be
                 reused *)
              let* () = TokenService.invalidate ctx ps in
              handler req
          | None ->
            (* Give 403 if provided secret does not exist *)
            Http.Response.(create () |> set_status 403) |> Lwt.return)
    in
    Opium_kernel.Rock.Middleware.create ~name:"csrf" ~filter
  ;;
end
