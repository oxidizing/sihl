let log_src = Logs.Src.create "sihl.middleware.session"

module Logs = (val Logs.src_log log_src : Logs.LOG)
module Map = Map.Make (String)

module Session = struct
  type t = string Map.t

  let empty = Map.empty

  let of_yojson yojson =
    let open Yojson.Safe.Util in
    let session_list =
      try
        Some (yojson |> to_assoc |> List.map (fun (k, v) -> k, to_string v))
      with
      | _ -> None
    in
    session_list |> Option.map List.to_seq |> Option.map Map.of_seq
  ;;

  let to_yojson session =
    `Assoc
      (session
      |> Map.to_seq
      |> List.of_seq
      |> List.map (fun (k, v) -> k, `String v))
  ;;

  let of_json json =
    try of_yojson (Yojson.Safe.from_string json) with
    | _ -> None
  ;;

  let to_json session = session |> to_yojson |> Yojson.Safe.to_string

  let to_sexp session =
    let open Sexplib0.Sexp_conv in
    let open Sexplib0.Sexp in
    let data =
      session
      |> Map.to_seq
      |> List.of_seq
      |> sexp_of_list (sexp_of_pair sexp_of_string sexp_of_string)
    in
    List [ List [ Atom "data"; data ] ]
  ;;
end

let decode_session cookie_key signed_with req =
  match Opium.Request.cookie ~signed_with cookie_key req with
  | None -> None
  | Some cookie_value ->
    (match Session.of_json cookie_value with
    | None ->
      Logs.err (fun m ->
          m
            "Failed to parse value found in session cookie '%s': '%s'"
            cookie_key
            cookie_value);
      Logs.info (fun m ->
          m
            "Maybe the cookie key '%s' collides with a cookie issued by \
             someone else. Try to change the cookie key."
            cookie_key);
      None
    | Some session -> Some session)
;;

let find
    ?(cookie_key = "_session")
    ?(secret = Core_configuration.read_secret ())
    key
    req
  =
  let signed_with = Opium.Cookie.Signer.make secret in
  let session = decode_session cookie_key signed_with req in
  Option.bind session (Map.find_opt key)
;;

let set
    ?(cookie_key = "_session")
    ?(secret = Core_configuration.read_secret ())
    session
    resp
  =
  let signed_with = Opium.Cookie.Signer.make secret in
  let session = session |> List.to_seq |> Map.of_seq in
  let cookie_value = Session.to_json session in
  let cookie = cookie_key, cookie_value in
  Opium.Response.add_cookie_or_replace
    ~scope:(Uri.of_string "/")
    ~sign_with:signed_with
    cookie
    resp
;;
