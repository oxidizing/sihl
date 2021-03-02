let log_src = Logs.Src.create "sihl.middleware.csrf"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let key : string Opium.Context.key =
  Opium.Context.Key.create ("csrf token", Sexplib.Std.sexp_of_string)
;;

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

let default_not_allowed_handler _ =
  Opium.Response.(of_plain_text ~status:`Forbidden "") |> Lwt.return
;;

let hash ~with_secret value =
  value
  |> Cstruct.of_string
  |> Mirage_crypto.Hash.mac `SHA1 ~key:(Cstruct.of_string with_secret)
  |> Cstruct.to_string
  |> Base64.encode_exn
;;

let verify ~with_secret ~hashed value =
  String.equal hashed (hash ~with_secret value)
;;

let middleware
    ?(not_allowed_handler = default_not_allowed_handler)
    ?(cookie_key = "__Host-csrf")
    ?(secret = Core_configuration.read_secret ())
    ()
  =
  let filter handler req =
    if Core_configuration.is_development ()
       && Option.value
            (Core_configuration.read_bool "FORCE_CSRF_CHECK")
            ~default:false
    then handler req
    else (
      let req, token = Web_form.consume req "csrf" in
      (* Create a new token for each request to mitigate BREACH attack *)
      let new_token = Core_random.base64 80 in
      let req = set new_token req in
      let construct_response handler =
        handler req
        |> Lwt.map
           @@ Opium.Response.add_cookie_or_replace
                ~scope:(Uri.of_string "/")
                ~secure:true
                (cookie_key, hash ~with_secret:secret new_token)
      in
      let is_safe =
        match req.Opium.Request.meth with
        | `GET | `HEAD | `OPTIONS | `TRACE -> true
        | _ -> false
      in
      match token, is_safe with
      (* Request is safe -> Allow access no matter what *)
      | _, true -> construct_response handler
      (* Request is unsafe, but no token provided -> Disallow access *)
      | None, false -> construct_response not_allowed_handler
      (* Request is unsafe and token provided -> Check if tokens match *)
      | Some received_token, false ->
        let stored_token = Opium.Request.cookie cookie_key req in
        (match stored_token with
        | None ->
          Logs.err (fun m ->
              m "No token stored for CSRF token '%s'" received_token);
          construct_response not_allowed_handler
        | Some stored_token ->
          if verify ~with_secret:secret ~hashed:stored_token received_token
          then construct_response handler
          else (
            Logs.err (fun m ->
                m
                  "Hashed stored token '%s' does not match with the hashed \
                   received token '%s'"
                  stored_token
                  received_token);
            construct_response not_allowed_handler)))
  in
  Rock.Middleware.create ~name:"csrf" ~filter
;;
