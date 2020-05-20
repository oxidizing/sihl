open Base

let ( let* ) = Lwt.bind

type content_type = Html | Json

let content_type = function Html -> "text/html" | Json -> "application/json"

let accepts_html req =
  Cohttp.Header.get (Opium.Std.Request.headers req) "Accept"
  |> Option.value_map ~default:false ~f:(fun a ->
         String.is_substring a ~substring:"text/html")

let require_auth req =
  match req |> Cohttp.Header.get_authorization with
  | None -> Core_err.raise_bad_request "No authorization header found"
  | Some token -> token

let find_in_query key query =
  query
  |> List.find ~f:(fun (k, _) -> String.equal k key)
  |> Option.map ~f:(fun (_, r) -> r)
  |> Option.bind ~f:List.hd

let query_opt req key =
  req |> Opium.Std.Request.uri |> Uri.query |> find_in_query key

let query req key =
  match query_opt req key with
  | None -> Core_err.raise_bad_request [%string "Please provide a key $(key)"]
  | Some value -> value

let query2_opt req key1 key2 = (query_opt req key1, query_opt req key2)

let query2 req key1 key2 = (query req key1, query req key2)

let query3_opt req key1 key2 key3 =
  (query_opt req key1, query_opt req key2, query_opt req key3)

let query3 req key1 key2 key3 = (query req key1, query req key2, query req key3)

let url_encoded ?body req key =
  (* we need to be able to pass in the body
     because Opium.Std.Request.body drains
     the body stream from the request *)
  let* body =
    match body with
    | Some body -> Lwt.return body
    | None -> req |> Opium.Std.Request.body |> Opium.Std.Body.to_string
  in
  match body |> Uri.pct_decode |> Uri.query_of_encoded |> find_in_query key with
  | None ->
      Lwt.return
      @@ Core_err.raise_bad_request [%string "Please provide a $(key)."]
  | Some value -> Lwt.return value

let url_encoded2 req key1 key2 =
  let* body = req |> Opium.Std.Request.body |> Opium.Std.Body.to_string in
  let* value1 = url_encoded ~body req key1 in
  let* value2 = url_encoded ~body req key2 in
  Lwt.return (value1, value2)

let param = Opium.Std.param

let param2 req key1 key2 = (param req key1, param req key2)

let param3 req key1 key2 key3 = (param req key1, param req key2, param req key3)

let require_body req decode =
  let* body = req |> Opium.Std.Request.body |> Cohttp_lwt.Body.to_string in
  body |> Core_json.parse |> Result.bind ~f:decode
  |> Result.map_error ~f:(fun error -> Core_err.err_bad_request error)
  |> Lwt.return

let require_body_exn req decode =
  let* body = require_body req decode in
  match body with
  | Ok body -> Lwt.return body
  | Error _ -> Core_err.raise_bad_request "invalid body provided"

include Opium.Std.Request
