open Core
open Opium.Std

let ( let* ) = Lwt.bind

let require_auth req =
  match req |> Cohttp.Header.get_authorization with
  | None -> failwith "No authorization header found"
  | Some token -> token

let query req key =
  let query = req |> Request.uri |> Uri.query in
  let value =
    query
    |> List.find ~f:(fun (k, _) -> String.equal k key)
    |> Option.map ~f:Tuple2.get2 |> Option.bind ~f:List.hd
  in
  match value with
  | None -> failwith @@ "required query not found key= " ^ key
  | Some value -> value

let query2 req key1 key2 = (query req key1, query req key2)

let query3 req key1 key2 key3 = (query req key1, query req key2, query req key3)

let param = Opium.Std.param

let param2 req key1 key2 = (param req key1, param req key2)

let param3 req key1 key2 key3 = (param req key1, param req key2, param req key3)

let require_body req decode =
  let* body = req |> Request.body |> Cohttp_lwt.Body.to_string in
  match body |> Yojson.Safe.from_string |> decode with
  | Ok body -> Lwt.return body
  | Error _ -> Fail.raise_bad_request "invalid body provided"

let failwith_opt msg opt =
  match opt with None -> failwith msg | Some value -> value

let failwith_result opt =
  match opt with Error msg -> failwith msg | Ok value -> value

module Msg = struct
  type t = { msg : string } [@@deriving yojson]

  let ok_string () = { msg = "ok" } |> to_yojson |> Yojson.Safe.to_string

  let msg_string msg = { msg } |> to_yojson |> Yojson.Safe.to_string
end

let code_of_error error =
  match error with
  | Fail.Error.BadRequest _ -> 400 |> Cohttp.Code.status_of_code
  | Fail.Error.Database _ -> 500 |> Cohttp.Code.status_of_code
  | Fail.Error.NoPermissions _ -> 403 |> Cohttp.Code.status_of_code
  | Fail.Error.NotAuthenticated _ -> 401 |> Cohttp.Code.status_of_code

let with_json :
    ?encode:('a -> Yojson.Safe.t) ->
    (Request.t -> 'a Lwt.t) ->
    Request.t ->
    Response.t Lwt.t =
 fun ?encode handler req ->
  let* result =
    Lwt.catch
      (fun () -> handler req |> Lwt.map (fun result -> Ok result))
      (fun exn -> Lwt.return @@ Fail.error_of_exn exn)
  in
  match (encode, result) with
  | Some encode, Ok result ->
      let response = result |> encode |> Yojson.Safe.to_string in
      respond' @@ `String response
  | None, Ok _ -> respond' @@ `String (Msg.ok_string ())
  | _, Error (Fail.Error.Database msg) ->
      let _ = Logs_lwt.err (fun m -> m "%s" msg) in
      respond'
      @@ `String
           ( Msg.msg_string
           @@ "Something went wrong, our administrators have been notified" )
  | _, Error error ->
      let msg = Fail.Error.show error in
      let _ = Logs_lwt.err (fun m -> m "%s" msg) in
      respond' ~code:(code_of_error error) (`String (Msg.msg_string @@ msg))
