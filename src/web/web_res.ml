type content_type = Html

type headers = (string * string) list

type t = {
  content_type : content_type;
  redirect : string option;
  content : string option;
}

let html = { content_type = Html; redirect = None; content = None }

let redirect path =
  { content_type = Html; redirect = Some path; content = None }

let content str req = { req with content = Some str }

let set_cookie ~key:_ ~data:_ _ = failwith "TODO set_cookie()"

(* type t = {
 *   content_type : content_type;
 *   body : string option;
 *   headers : headers;
 *   status : int;
 *   session : change_session;
 *   file : string option;
 * }
 *
 * let status status resp = { resp with status }
 *
 * let header key value resp =
 *   let headers = List.cons (key, value) resp.headers in
 *   { resp with headers }
 *
 * let headers headers resp = { resp with headers }
 *
 * let redirect path resp =
 *   {
 *     resp with
 *     status = 301;
 *     headers = List.cons ("Location", path) resp.headers;
 *   }
 *
 * let start_session token resp = { resp with session = SetSession token }
 *
 * let stop_session resp = { resp with session = EndSession }
 *
 * let empty =
 *   {
 *     content_type = Html;
 *     body = None;
 *     headers = [];
 *     status = 200;
 *     session = Nothing;
 *     file = None;
 *   }
 *
 * let json body =
 *   {
 *     content_type = Json;
 *     body = Some body;
 *     headers = [];
 *     status = 200;
 *     session = Nothing;
 *     file = None;
 *   }
 *
 * let html body =
 *   {
 *     content_type = Html;
 *     body = Some body;
 *     headers = [];
 *     status = 200;
 *     session = Nothing;
 *     file = None;
 *   }
 *
 * let file path =
 *   {
 *     content_type = Html;
 *     body = None;
 *     headers = [];
 *     status = 200;
 *     session = Nothing;
 *     file = Some path;
 *   }
 *
 * let to_cohttp resp =
 *   let headers = Cohttp.Header.of_list resp.headers in
 *   let headers =
 *     Cohttp.Header.add headers "Content-Type" (content_type resp.content_type)
 *   in
 *   let code = Cohttp.Code.status_of_code resp.status in
 *   let body =
 *     match (resp.body, resp.file) with
 *     | Some body, _ -> `String body
 *     | _, Some path -> `String path
 *     | _ -> `String Msg.ok_string
 *   in
 *   let co_resp = Opium.Std.respond ~headers ~code body in
 *   match resp.session with
 *   | Nothing -> co_resp
 *   | SetSession token ->
 *       (\* TODO move session cookie into http_session.ml *\)
 *       Opium.Std.Cookie.set ~http_only:true ~secure:false ~key:"session_id"
 *         ~data:token co_resp
 *   | EndSession ->
 *       (\* TODO move session cookie into http_session.ml *\)
 *       Opium.Std.Cookie.set
 *         ~expiration:(`Max_age (Int64.of_int 0))
 *         ~http_only:true ~secure:false ~key:"session_id" ~data:"session_ended"
 *         co_resp *)
