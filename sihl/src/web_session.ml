let log_src = Logs.Src.create "sihl.middleware.session"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let decode_session cookie_key cookie_value =
  match cookie_value with
  | None -> Ok None
  | Some cookie_value ->
    (match Session.of_json cookie_value with
     | None ->
       let err_msg =
         Format.asprintf
           "Failed to parse value found in session cookie '%s': '%s'"
           cookie_key
           cookie_value
       in
       Logs.err (fun m -> m "%s" err_msg);
       Logs.info (fun m ->
         m
           "Maybe the cookie key '%s' collides with a cookie issued by someone \
            else. Try to change the cookie key."
           cookie_key);
       Error err_msg
     | Some session -> Ok (Some session))
;;

let decode_session_req cookie_key signed_with req =
  Opium.Request.cookie ~signed_with cookie_key req |> decode_session cookie_key
;;

let decode_session_resp cookie_key signed_with resp =
  Opium.Response.cookie ~signed_with cookie_key resp
  |> Option.map (fun c -> snd c.Opium.Cookie.value)
  |> decode_session cookie_key
;;

let find
  ?(cookie_key = "_session")
  ?(secret = Core_configuration.read_secret ())
  key
  req
  =
  let signed_with = Opium.Cookie.Signer.make secret in
  let session =
    decode_session_req cookie_key signed_with req |> CCResult.get_or_failwith
  in
  Option.bind session (Session.StrMap.find_opt key)
;;

let get_all
  ?(cookie_key = "_session")
  ?(secret = Core_configuration.read_secret ())
  req
  =
  let open CCOption.Infix in
  let signed_with = Opium.Cookie.Signer.make secret in
  decode_session_req cookie_key signed_with req
  |> CCResult.get_or_failwith
  >|= Session.StrMap.to_seq
  >|= List.of_seq
;;

let set
  ?(cookie_key = "_session")
  ?(secret = Core_configuration.read_secret ())
  ?(expires = `Session)
  ?(scope = Uri.of_string "/")
  ?(same_site = `Lax)
  ?(secure = false)
  ?(http_only = false)
  session
  resp
  =
  let signed_with = Opium.Cookie.Signer.make secret in
  let session = session |> List.to_seq |> Session.StrMap.of_seq in
  let cookie_value = Session.to_json session in
  let cookie = cookie_key, cookie_value in
  Opium.Response.add_cookie_or_replace
    ~expires:expires
    ~scope:scope
    ~same_site:same_site
    ~secure:secure
    ~http_only:http_only
    ~sign_with:signed_with
    cookie
    resp
;;

let update_or_set_value
  ?(cookie_key = "_session")
  ?(secret = Core_configuration.read_secret ())
  ?(expires : Opium.Cookie.expires option)
  ~key
  f
  req
  resp
  =
  let signed_with = Opium.Cookie.Signer.make secret in
  let mreq =
    decode_session_req cookie_key signed_with req |> CCResult.get_or_failwith
  in
  let mresp =
    decode_session_resp cookie_key signed_with resp |> CCResult.get_or_failwith
  in
  let updated_session =
    match mreq, mresp with
    | None, None -> Session.StrMap.empty |> Session.StrMap.update key f
    | None, Some m | Some m, None -> Session.StrMap.update key f m
    | Some mreq, Some mresp ->
      Session.StrMap.union (fun _ _ rp -> Some rp) mreq mresp
      |> Session.StrMap.update key f
  in
  let cookie_value = Session.to_json updated_session in
  let cookie = cookie_key, cookie_value in
  Opium.Response.add_cookie_or_replace
    ~scope:(Uri.of_string "/")
    ~sign_with:signed_with
    ?expires
    cookie
    resp
;;

(* TODO improve API, don't take req maybe *)
let set_value
  ?(cookie_key = "_session")
  ?(secret = Core_configuration.read_secret ())
  ?expires
  ~key
  value
  req
  resp
  =
  update_or_set_value
    ~cookie_key
    ~secret
    ?expires
    ~key
    (CCFun.const @@ Some value)
    req
    resp
;;
