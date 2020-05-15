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
  (* we need to be able to pass in the body because Opium.Std.Request.body drains
     the body stream from the request *)
  let* body =
    match body with
    | Some body -> Lwt.return body
    | None -> req |> Opium.Std.Request.body |> Opium.Std.Body.to_string
  in
  match body |> Uri.pct_decode |> Uri.query_of_encoded |> find_in_query key with
  | None ->
      Lwt.return @@ Core_err.raise_bad_request [%string "Please provide a $(key)."]
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

module Msg = struct
  type t = { msg : string } [@@deriving yojson]

  let ok_string = { msg = "ok" } |> to_yojson |> Core_json.to_string

  let msg_string msg = { msg } |> to_yojson |> Core_json.to_string
end

let code_of_error error =
  match error with
  | Core_err.Error.BadRequest _ -> 400 |> Cohttp.Code.status_of_code
  | Core_err.Error.NoPermissions _ -> 403 |> Cohttp.Code.status_of_code
  | Core_err.Error.NotAuthenticated _ -> 401 |> Cohttp.Code.status_of_code
  | Core_err.Error.Configuration _ | Core_err.Error.Email _ | Core_err.Error.Database _
  | Core_err.Error.Server _ ->
      500 |> Cohttp.Code.status_of_code

module Response = struct
  type headers = (string * string) list

  type change_session = Nothing | SetSession of string | EndSession

  type t = {
    content_type : content_type;
    body : string option;
    headers : headers;
    status : int;
    session : change_session;
    file : string option;
  }

  let status status resp = { resp with status }

  let header key value resp =
    let headers = List.cons (key, value) resp.headers in
    { resp with headers }

  let headers headers resp = { resp with headers }

  let redirect path resp =
    {
      resp with
      status = 301;
      headers = List.cons ("Location", path) resp.headers;
    }

  let start_session token resp = { resp with session = SetSession token }

  let stop_session resp = { resp with session = EndSession }

  let empty =
    {
      content_type = Html;
      body = None;
      headers = [];
      status = 200;
      session = Nothing;
      file = None;
    }

  let json body =
    {
      content_type = Json;
      body = Some body;
      headers = [];
      status = 200;
      session = Nothing;
      file = None;
    }

  let html body =
    {
      content_type = Html;
      body = Some body;
      headers = [];
      status = 200;
      session = Nothing;
      file = None;
    }

  let file path =
    {
      content_type = Html;
      body = None;
      headers = [];
      status = 200;
      session = Nothing;
      file = Some path;
    }

  let to_cohttp resp =
    let headers = Cohttp.Header.of_list resp.headers in
    let headers =
      Cohttp.Header.add headers "Content-Type" (content_type resp.content_type)
    in
    let code = Cohttp.Code.status_of_code resp.status in
    let body =
      match (resp.body, resp.file) with
      | Some body, _ -> `String body
      | _, Some path -> `String path
      | _ -> `String Msg.ok_string
    in
    let co_resp = Opium.Std.respond ~headers ~code body in
    match resp.session with
    | Nothing -> co_resp
    | SetSession token ->
        Opium.Std.Cookie.set ~http_only:true ~secure:false ~key:"session_id"
          ~data:token co_resp
    | EndSession ->
        Opium.Std.Cookie.set
          ~expiration:(`Max_age (Int64.of_int 0))
          ~http_only:true ~secure:false ~key:"session_id" ~data:"session_ended"
          co_resp
end

let handle handler req = req |> handler |> Lwt.map Response.to_cohttp

let get path handler = Opium.Std.get path (handle handler)

let post path handler = Opium.Std.post path (handle handler)

let delete path handler = Opium.Std.delete path (handle handler)

let put path handler = Opium.Std.put path (handle handler)

let all path handler = Opium.Std.all path (handle handler)

module Request = Opium.Std.Request
