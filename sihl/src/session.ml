(* Utility functions for tests *)
module StrMap = Map.Make (String)

let of_yojson yojson =
  let open Yojson.Safe.Util in
  let session_list =
    try
      Some (yojson |> to_assoc |> List.map (fun (k, v) -> k, to_string v))
    with
    | _ -> None
  in
  session_list |> Option.map (fun s -> s |> List.to_seq |> StrMap.of_seq)
;;

let of_json json =
  try of_yojson (Yojson.Safe.from_string json) with
  | _ -> None
;;

let to_yojson session =
  `Assoc
    (session
    |> StrMap.to_seq
    |> List.of_seq
    |> List.map (fun (k, v) -> k, `String v))
;;

let to_json session = session |> to_yojson |> Yojson.Safe.to_string

let to_sexp session =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  let data =
    session
    |> StrMap.to_seq
    |> List.of_seq
    |> sexp_of_list (sexp_of_pair sexp_of_string sexp_of_string)
  in
  List [ List [ Atom "data"; data ] ]
;;

let decode_session resp =
  let signed_with =
    Opium.Cookie.Signer.make (Core_configuration.read_secret ())
  in
  match Opium.Response.cookie ~signed_with "_session" resp with
  | None -> None
  | Some cookie_value ->
    let _, value = cookie_value.Opium.Cookie.value in
    of_json value
;;

let get_all_resp resp =
  let session = decode_session resp in
  session |> CCOpt.map (fun s -> s |> StrMap.to_seq |> List.of_seq)
;;

let find_resp key resp =
  let session = decode_session resp in
  Option.bind session (StrMap.find_opt key) |> Option.get
;;

let set_value_req session req =
  let signed_with =
    Opium.Cookie.Signer.make (Core_configuration.read_secret ())
  in
  let session = session |> List.to_seq |> StrMap.of_seq in
  let cookie_value = to_json session in
  let cookie = "_session", cookie_value in
  Opium.Request.add_cookie ~sign_with:signed_with cookie req
;;
