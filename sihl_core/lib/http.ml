open Base

let ( let* ) = Lwt.bind

let require_auth req =
  match req |> Cohttp.Header.get_authorization with
  | None -> Fail.raise_bad_request "No authorization header found"
  | Some token -> token

let query_opt req key =
  let query = req |> Opium.Std.Request.uri |> Uri.query in
  query
  |> List.find ~f:(fun (k, _) -> String.equal k key)
  |> Option.map ~f:(fun (_, r) -> r)
  |> Option.bind ~f:List.hd

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

module Middleware = struct
  (* TODO
     1. check Accept header
     2. if json: return {msg: "..."} with error message
     3. if html: set error message in session
     4. redirect to same redirect.path, if 404 redirect to 404 page
  *)
  let handle_error app =
    let filter (handler : Opium.Std.Request.t -> Opium.Std.Response.t Lwt.t)
        (req : Opium.Std.Request.t) =
      let* response = Fail.try_to_run (fun () -> handler req) in
      match response with
      | Ok response -> Lwt.return response
      | Error error ->
          let msg = Fail.Error.show error in
          let _ = Logs_lwt.err (fun m -> m "%s" msg) in
          Opium.Std.respond' ~code:(code_of_error error)
            (`String (Msg.msg_string @@ msg))
    in
    let m = Opium.Std.Rock.Middleware.create ~name:"error handler" ~filter in
    Opium.Std.middleware m app
end

module Response = struct
  type content_type = Html | Json

  let content_type = function Html -> "text/html" | Json -> "application/json"

  type headers = (string * string) list

  type t = {
    content_type : content_type;
    body : string option;
    headers : headers;
    status : int;
  }

  let status status resp = { resp with status }

  let header key value resp =
    let headers = List.cons (key, value) resp.headers in
    { resp with headers }

  let headers headers resp = { resp with headers }

  let json body =
    { content_type = Json; body = Some body; headers = []; status = 200 }

  let html body =
    { content_type = Html; body = Some body; headers = []; status = 200 }

  let empty = { content_type = Html; body = None; headers = []; status = 200 }

  let to_cohttp resp =
    let headers = Cohttp.Header.of_list resp.headers in
    let headers =
      Cohttp.Header.add headers "Content-Type" (content_type resp.content_type)
    in
    let code = Cohttp.Code.status_of_code resp.status in
    let body = resp.body |> Option.value ~default:Msg.ok_string in
    Opium.Std.respond ~headers ~code (`String body)
end

let handle handler req = req |> handler |> Lwt.map Response.to_cohttp

let get path handler = Opium.Std.get path (handle handler)

let post path handler = Opium.Std.post path (handle handler)

let delete path handler = Opium.Std.delete path (handle handler)

let put path handler = Opium.Std.put path (handle handler)

module Request = Opium.Std.Request
