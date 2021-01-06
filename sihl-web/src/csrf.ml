open Lwt.Syntax

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
    Logs.info (fun m ->
        m "Have you applied the CSRF middleware for this route?");
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

let xor c1 c2 =
  try
    Some
      (List.map2
         (fun chr1 chr2 -> Char.chr (Char.code chr1 lxor Char.code chr2))
         c1
         c2)
  with
  | exn ->
    Logs.err (fun m ->
        m
          "Failed to XOR %s and %s. %s"
          (c1 |> List.to_seq |> Caml.String.of_seq)
          (c2 |> List.to_seq |> Caml.String.of_seq)
          (Printexc.to_string exn));
    None
;;

let decrypt_with_salt ~salted_cipher ~salt_length =
  if List.length salted_cipher - salt_length != salt_length
  then (
    Logs.err (fun m ->
        m
          "Failed to decrypt cipher %s. Salt length does not match cipher \
           length."
          (salted_cipher |> List.to_seq |> Caml.String.of_seq));
    None)
  else (
    try
      let salt = CCList.take salt_length salted_cipher in
      let encrypted_value = CCList.drop salt_length salted_cipher in
      xor salt encrypted_value
    with
    | exn ->
      Logs.err (fun m ->
          m
            "Failed to decrypt cipher %s. %s"
            (salted_cipher |> List.to_seq |> Caml.String.of_seq)
            (Printexc.to_string exn));
      None)
;;

(* TODO (https://docs.djangoproject.com/en/3.0/ref/csrf/#how-it-works) Check other Django
   specifics namely:
 * Testing views with custom HTTP client
 * Allow Sihl user to make views exempt
 * Enable subdomain
 * HTML caching token handling
 *)

let create_token session =
  let token = Sihl_core.Random.base64 80 in
  let* () = Sihl_facade.Session.set_value session ~k:"csrf" ~v:(Some token) in
  Lwt.return token
;;

let secret_to_token secret =
  (* Randomize and scramble secret (XOR with salt) to make a token *)
  (* Do this to mitigate BREACH attacks: http://breachattack.com/#mitigations *)
  let secret_length = String.length secret in
  let salt = Sihl_facade.Random.bytes secret_length in
  let secret_value = secret |> String.to_seq |> List.of_seq in
  let encrypted =
    match xor salt secret_value with
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

let default_not_allowed_handler _ =
  Opium.Response.(of_plain_text ~status:`Forbidden "") |> Lwt.return
;;

let middleware
    ?(not_allowed_handler = default_not_allowed_handler)
    ?(key = "csrf")
    ()
  =
  let filter handler req =
    let session = Session.find req in
    let req, secret = Form.consume req "csrf" in
    let is_safe =
      match req.Opium.Request.meth with
      | `GET | `HEAD | `OPTIONS | `TRACE -> true
      | _ -> false
    in
    match secret, is_safe with
    | None, true ->
      (* Don't check for CSRF token in GET requests *)
      let* stored_token = Sihl_facade.Session.find_value session key in
      (match stored_token with
      | Some token ->
        let req = set token req in
        handler req
      | None ->
        let* token = create_token session in
        let req = set token req in
        handler req)
    | None, false -> not_allowed_handler req
    | Some secret, true ->
      let token = secret_to_token secret in
      let req = set token req in
      handler req
    | Some secret, false ->
      let token = secret_to_token secret in
      let req = set token req in
      let decoded = Base64.decode ~alphabet:Base64.uri_safe_alphabet token in
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
          decrypt_with_salt
            ~salted_cipher
            ~salt_length:(List.length salted_cipher / 2)
        with
        | None ->
          Logs.err (fun m -> m "Failed to decrypt CSRF token %s " token);
          raise @@ Crypto_failed "Failed to decrypt CSRF token"
        | Some dec -> dec
      in
      let received_token = decrypted_secret |> List.to_seq |> String.of_seq in
      let* stored_token = Sihl_facade.Session.find_value session key in
      (match stored_token with
      | Some stored_token ->
        if not @@ String.equal stored_token received_token
        then (
          Logs.err (fun m ->
              m "Associated CSRF token does not match with received token");
          not_allowed_handler req)
        else
          (* Provided secret matches and is valid => Invalidate it so it can't
             be reused *)
          let* () = Sihl_facade.Session.set_value session ~k:key ~v:None in
          (* To allow fetching a new valid token from the context, generate a
             new one *)
          let* token = create_token session in
          let req = set token req in
          handler req
      | None ->
        Logs.err (fun m -> m "No token associated with CSRF token");
        not_allowed_handler req)
  in
  Rock.Middleware.create ~name:"csrf" ~filter
;;
