type content_type = Html | Json

let content_type = function Html -> "text/html" | Json -> "application/json"

module Msg = struct
  type t = { msg : string } [@@deriving yojson]

  let ok_string = { msg = "ok" } |> to_yojson |> Core_json.to_string

  let msg_string msg = { msg } |> to_yojson |> Core_json.to_string
end

exception BadRequest of string option

exception NotFound of string option

exception Authentication of string option

exception Authorization of string option

exception Internal of string option

let fail = function
  | `BadRequest msg -> raise @@ BadRequest msg
  | `NotFound msg -> raise @@ NotFound msg
  | `Authentication msg -> raise @@ Authentication msg
  | `Authorization msg -> raise @@ Authorization msg
  | `Internal msg -> raise @@ Internal msg

let of_exn = function
  | BadRequest (Some msg) -> Core_error.bad_request ~msg ()
  | BadRequest None -> Core_error.bad_request ()
  | NotFound (Some msg) -> Core_error.not_found ~msg ()
  | NotFound None -> Core_error.not_found ()
  | Authentication _ -> Core_error.authentication ()
  | Authorization _ -> Core_error.authorization ()
  | Internal (Some msg) -> Core_error.authorization ~msg ()
  | exn ->
      Logs.err (fun m -> m "Unspecified exception: %s" (Printexc.to_string exn));
      Core_error.internal ()

let try_run f =
  Lwt.catch
    (fun () -> f () |> Lwt.map (fun result -> Ok result))
    (fun exn -> Lwt.return @@ Error (of_exn exn))

let code_of_error = function
  | `BadRequest _ -> 400 |> Cohttp.Code.status_of_code
  | `NotFound _ -> 404 |> Cohttp.Code.status_of_code
  | `Authentication _ -> 401 |> Cohttp.Code.status_of_code
  | `Authorization _ -> 403 |> Cohttp.Code.status_of_code
  | _ -> 500 |> Cohttp.Code.status_of_code

let error_to_msg = function
  | `BadRequest (Some msg) -> msg
  | `BadRequest None -> "Bad request"
  | `NotFound (Some msg) -> msg
  | `NotFound None -> "Not found"
  | `Authentication (Some msg) -> msg
  | `Authentication None -> "Not authenticated"
  | `Authorization (Some msg) -> msg
  | `Authorization None -> "Not allowed"
  | _ -> "An error occurred, our administrators have been notified"

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
      (* TODO move session cookie into http_session.ml *)
      Opium.Std.Cookie.set ~http_only:true ~secure:false ~key:"session_id"
        ~data:token co_resp
  | EndSession ->
      (* TODO move session cookie into http_session.ml *)
      Opium.Std.Cookie.set
        ~expiration:(`Max_age (Int64.of_int 0))
        ~http_only:true ~secure:false ~key:"session_id" ~data:"session_ended"
        co_resp
