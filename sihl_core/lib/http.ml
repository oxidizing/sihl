open Base

let ( let* ) = Lwt.bind

type content_type = Html | Json

let content_type = function Html -> "text/html" | Json -> "application/json"

let require_auth req =
  match req |> Cohttp.Header.get_authorization with
  | None -> Fail.raise_bad_request "No authorization header found"
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
  | None -> Fail.raise_bad_request "required query not found key= " ^ key
  | Some value -> value

let query2_opt req key1 key2 = (query_opt req key1, query_opt req key2)

let query2 req key1 key2 = (query req key1, query req key2)

let query3_opt req key1 key2 key3 =
  (query_opt req key1, query_opt req key2, query_opt req key3)

let query3 req key1 key2 key3 = (query req key1, query req key2, query req key3)

let param = Opium.Std.param

let param2 req key1 key2 = (param req key1, param req key2)

let param3 req key1 key2 key3 = (param req key1, param req key2, param req key3)

let require_body req decode =
  let* body = req |> Opium.Std.Request.body |> Cohttp_lwt.Body.to_string in
  body |> Json.parse |> Result.bind ~f:decode
  |> Result.map_error ~f:(fun error -> Fail.err_bad_request error)
  |> Lwt.return

let require_body_exn req decode =
  let* body = require_body req decode in
  match body with
  | Ok body -> Lwt.return body
  | Error _ -> Fail.raise_bad_request "invalid body provided"

module Msg = struct
  type t = { msg : string } [@@deriving yojson]

  let ok_string = { msg = "ok" } |> to_yojson |> Json.to_string

  let msg_string msg = { msg } |> to_yojson |> Json.to_string
end

let code_of_error error =
  match error with
  | Fail.Error.BadRequest _ -> 400 |> Cohttp.Code.status_of_code
  | Fail.Error.NoPermissions _ -> 403 |> Cohttp.Code.status_of_code
  | Fail.Error.NotAuthenticated _ -> 401 |> Cohttp.Code.status_of_code
  | Fail.Error.Configuration _ | Fail.Error.Email _ | Fail.Error.Database _
  | Fail.Error.Server _ ->
      500 |> Cohttp.Code.status_of_code

let handle_error_m app =
  let filter handler req =
    let* response = Fail.try_to_run (fun () -> handler req) in
    let accepts_html =
      Cohttp.Header.get (Opium.Std.Request.headers req) "Accept"
      |> Option.value_map ~default:false ~f:(fun a ->
             String.is_substring a ~substring:"text/html")
    in
    match (accepts_html, response) with
    | _, Ok response -> Lwt.return response
    | false, Error error ->
        let msg = Fail.Error.show error in
        Logs.err (fun m -> m "%s" msg);
        let headers =
          Cohttp.Header.of_list [ ("Content-Type", "application/json") ]
        in
        let body = Cohttp_lwt.Body.of_string @@ Msg.msg_string msg in
        Opium.Std.Response.create ~headers ~body ~code:(code_of_error error) ()
        |> Lwt.return
    | ( true,
        Error (Fail.Error.NotAuthenticated msg | Fail.Error.NoPermissions msg) )
      ->
        (* TODO set flash to msg, redirect to some default location *)
        Logs.err (fun m -> m "%s" msg);
        (* TODO evaluate whether the error handler should really remove invalid cookies *)
        let headers =
          Cohttp.Header.of_list
            [ ("Content-Type", "text/html"); ("Location", "/admin/login/") ]
        in
        let body = Cohttp_lwt.Body.of_string @@ Msg.msg_string msg in
        Opium.Std.Response.create ~headers ~body ~code:`Moved_permanently ()
        |> Opium.Std.Cookie.set
             ~expiration:(`Max_age (Int64.of_int 0))
             ~http_only:true ~secure:false ~key:"session_id"
             ~data:"session_ended"
        |> Lwt.return
    | ( true,
        Error
          ( Fail.Error.BadRequest msg
          | Fail.Error.Configuration msg
          | Fail.Error.Database msg
          | Fail.Error.Email msg
          | Fail.Error.Server msg ) ) ->
        (* TODO set flash to msg, redirect to some default location *)
        Logs.err (fun m -> m "%s" msg);
        let headers =
          Cohttp.Header.of_list
            (* TODO forward to custom error page *)
            [ ("Content-Type", "text/html"); ("Location", "/admin/dashboard/") ]
        in
        let body = Cohttp_lwt.Body.of_string @@ Msg.msg_string msg in
        Opium.Std.Response.create ~headers ~body ~code:`Moved_permanently ()
        |> Lwt.return
  in

  let m = Opium.Std.Rock.Middleware.create ~name:"error handler" ~filter in
  Opium.Std.middleware m app

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
