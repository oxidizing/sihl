let log_src = Logs.Src.create "sihl.middleware.csrf"

module Logs = (val Logs.src_log log_src : Logs.LOG)

exception Exception of string

let key : string Opium.Context.key =
  Opium.Context.Key.create ("csrf token", Sexplib.Std.sexp_of_string)
;;

(* Can be used to fetch token in view for forms *)
let find req = Opium.Context.find key req.Opium.Request.env

let find_exn req =
  match Opium.Context.find key req.Opium.Request.env with
  | Some csrf -> csrf
  | None ->
    failwith "CSRF token was fetched but CSRF middleware is not installed"
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

module Crypto = struct
  let () = Mirage_crypto_rng_unix.use_default ()
  let block_size = 16

  (** [token_length] is the amount of bytes used in the unencrypted CSRF tokens.
  *)
  let token_length = 4 * block_size

  module Secret : sig
    type t

    (** [make raw] turns a [raw] string secret to a fixed length SHA256 digest.
        A fixed length secret is required for the hard-coded AES key sizes to
        work. *)
    val make : string -> t

    (** [to_raw secret] turns a [secret] into a [Cstruct.t]. *)
    val to_raw : t -> Cstruct.t
  end = struct
    type t = Cstruct.t

    let make secret =
      secret
      |> Digestif.SHA256.digest_string
      |> Digestif.SHA256.to_raw_string
      |> Cstruct.of_string
    ;;

    let to_raw = CCFun.id
  end

  module Encrypted_token : sig
    type t

    (** [equal tkn1 tkn2] checks if two encrypted tokens [tkn1] and [tkn2] are
        equal. *)
    val equal : t -> t -> bool

    (** [to_uri_safe_string tkn] turns an encrypted token [tkn] into a URI-safe
        base64 string. Used to make sure CSRF works with all encodings. *)
    val to_uri_safe_string : t -> string

    (** [of_uri_safe_string tkn] turns a URI-safe string [tkn] into an encrypted
        token. Attempts to parse the base64 input [tkn], which can fail. This
        does not perform any cryptographic operation to ensure [tkn] can be
        decrypted. *)
    val of_uri_safe_string : string -> t option

    (** [to_struct tkn] turns an encrypted token [tkn] to a raw format. *)
    val to_struct : t -> Cstruct.t

    (** [from_struct ~with_secret tkn] encrypts a raw token [tkn] using AES in
        ECB mode given a secret [with_secret]. *)
    val from_struct : with_secret:Secret.t -> Cstruct.t -> t

    (** [from_struct_random ~with_secret tkn] encrypts a raw token [tkn].
        Additionally the encrypted result is scrambled with a random salt (IV)
        using AES in CBC mode given a secret [with_secret].*)
    val from_struct_random : with_secret:Secret.t -> Cstruct.t -> t
  end = struct
    type t = Cstruct.t

    let equal = Cstruct.equal

    let to_uri_safe_string t =
      t
      |> Cstruct.to_string
      |> Base64.encode_string ~alphabet:Base64.uri_safe_alphabet
    ;;

    let of_uri_safe_string t =
      t
      |> Base64.decode ~alphabet:Base64.uri_safe_alphabet
      |> CCResult.to_opt
      |> CCOption.map Cstruct.of_string
    ;;

    let to_struct = CCFun.id

    let from_struct ~with_secret value =
      let open Cstruct in
      let open Mirage_crypto.AES.ECB in
      let key = with_secret |> Secret.to_raw |> to_string |> of_secret in
      encrypt ~key (to_string value) |> of_string
    ;;

    let from_struct_random ~with_secret value =
      let open Cstruct in
      let open Mirage_crypto.AES.CBC in
      let key = with_secret |> Secret.to_raw |> to_string |> of_secret in
      let iv = Mirage_crypto_rng.generate block_size in
      append (of_string iv) @@ (encrypt ~key ~iv (to_string value) |> of_string)
    ;;
  end

  (** This module does not provide an API to read a decrypted token (by turning
      it into a string, Cstruct.t or similar). This is to prevent leaking CSRF
      tokens. *)
  module Decrypted_token : sig
    type t

    (** [equal tkn1 tkn2] checks if two decrypted tokens [tkn1] and [tkn2] are
        equal. *)
    val equal : t -> t -> bool

    (** [equal_struct tkn raw] checks if a decrypted token [tkn] is equal to a
        raw token [raw]. *)
    val equal_struct : t -> Cstruct.t -> bool

    (** [from_encrypted ~with_secret tkn] decrypts an encrypted token [tkn]
        using AES in ECB mode given a secret [with_secret]. *)
    val from_encrypted : with_secret:Secret.t -> Encrypted_token.t -> t

    (** [from_encrypted_random ~with_secret tkn] decrypts a randomized encrypted
        token [tkn] given a secret [with_secret]. This function reverses
        [Encrypted_token.from_struct_random] since a specific format is
        required. *)
    val from_encrypted_random : with_secret:Secret.t -> Encrypted_token.t -> t

    (** [from_encrypted_to_encrypted_random ~with_secret tkn] turns a normal
        encrypted token [tkn] into a randomly encrypted token by first
        decrypting it and then re-encrypting it with
        [Encrypted_token.from_struct_random].*)
    val from_encrypted_to_encrypted_random
      :  with_secret:Secret.t
      -> Encrypted_token.t
      -> Encrypted_token.t
  end = struct
    type t = Cstruct.t

    let equal = Cstruct.equal
    let equal_struct = equal

    let from_encrypted ~with_secret (value : Encrypted_token.t) : Cstruct.t =
      let open Cstruct in
      let open Mirage_crypto.AES.ECB in
      let key = with_secret |> Secret.to_raw |> to_string |> of_secret in
      decrypt ~key (Encrypted_token.to_struct value |> to_string) |> of_string
    ;;

    let from_encrypted_random ~with_secret (value : Encrypted_token.t)
      : Cstruct.t
      =
      let open Cstruct in
      let open Mirage_crypto.AES.CBC in
      let key = with_secret |> Secret.to_raw |> to_string |> of_secret in
      let iv, value =
        value
        |> Encrypted_token.to_struct
        |> CCFun.flip Cstruct.split block_size
      in
      decrypt ~key ~iv:(to_string iv) (to_string value) |> of_string
    ;;

    let from_encrypted_to_encrypted_random ~with_secret value =
      from_encrypted ~with_secret value
      |> Encrypted_token.from_struct_random ~with_secret
    ;;
  end
end

let default_not_allowed_handler _ =
  Opium.Response.(of_plain_text ~status:`Forbidden "") |> Lwt.return
;;

let middleware
      ?(not_allowed_handler = default_not_allowed_handler)
      ?(key = "_csrf")
      ?(session_key = "_session")
      ?(input_name = "_csrf")
      ?(secret = Core_configuration.read_secret ())
      ?(expires : Opium.Cookie.expires option)
      ()
  =
  let open Crypto in
  let block_secret = Secret.make secret in
  let filter handler req =
    let check_csrf =
      Core_configuration.is_production ()
      || Option.value (Core_configuration.read_bool "CHECK_CSRF") ~default:false
    in
    if not check_csrf
    then
      (* Set fake token since CSRF is disabled *)
      handler (set "development" req)
    else
      let
      (* CSRF token might come from a multipart form *)
      open
        CCOption.Infix in
      let%lwt multipart = Opium.Request.to_multipart_form_data req in
      let%lwt received_encrypted_token =
        multipart
        >>= List.assoc_opt input_name
        |> (function
         | None -> Opium.Request.urlencoded input_name req
         | tkn -> Lwt.return tkn)
        |> Lwt.map (CCOption.flat_map Encrypted_token.of_uri_safe_string)
      in
      let stored_encrypted_token =
        Web_session.find key req >>= Encrypted_token.of_uri_safe_string
      in
      (* Create a new randomized, decryptable token for each request to mitigate
         BREACH attack *)
      let storable_encrypted_token, submittable_encrypted_token =
        match stored_encrypted_token with
        | Some tkn ->
          ( tkn
          , Decrypted_token.from_encrypted_to_encrypted_random
              ~with_secret:block_secret
              tkn )
        | None ->
          let value =
            Mirage_crypto_rng.generate token_length |> Cstruct.of_string
          in
          ( Encrypted_token.from_struct ~with_secret:block_secret value
          , Encrypted_token.from_struct_random ~with_secret:block_secret value )
      in
      let req =
        set
          (submittable_encrypted_token |> Encrypted_token.to_uri_safe_string)
          req
      in
      let construct_response handler =
        let tkn = Encrypted_token.to_uri_safe_string storable_encrypted_token in
        handler req
        |> Lwt.map
           @@ fun resp ->
           (* Try to add csrf to session, if it does not exist, make a new
              session *)
           (* If expires is not set, token expires when session expires *)
           Web_session.set_value
             ~cookie_key:session_key
             ~secret
             ~key
             ?expires
             tkn
             req
             resp
      in
      let is_safe =
        match req.Opium.Request.meth with
        | `GET | `HEAD | `OPTIONS | `TRACE -> true
        | _ -> false
      in
      match received_encrypted_token, is_safe with
      (* Request is safe -> Allow access no matter what *)
      | _, true -> construct_response handler
      (* Request is unsafe, but no token provided -> Disallow access *)
      | None, false -> construct_response not_allowed_handler
      (* Request is unsafe and token provided -> Check if tokens match *)
      | Some received_encrypted_token, false ->
        (match stored_encrypted_token with
         | None ->
           Logs.err (fun m ->
             m
               "No token stored in session for received CSRF token '%s'"
               (Encrypted_token.to_uri_safe_string received_encrypted_token));
           construct_response not_allowed_handler
         | Some stored_encrypted_token ->
           let stored_token =
             Decrypted_token.from_encrypted
               ~with_secret:block_secret
               stored_encrypted_token
           in
           let received_token =
             Decrypted_token.from_encrypted_random
               ~with_secret:block_secret
               received_encrypted_token
           in
           if Decrypted_token.equal stored_token received_token
           then construct_response handler
           else (
             Logs.err (fun m ->
               m
                 "Encrypted stored token '%s' does not match with the received \
                  encrypted token '%s'"
                 (Encrypted_token.to_uri_safe_string stored_encrypted_token)
                 (Encrypted_token.to_uri_safe_string received_encrypted_token));
             construct_response not_allowed_handler))
  in
  Rock.Middleware.create ~name:"csrf" ~filter
;;
