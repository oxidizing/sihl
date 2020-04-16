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
  | Error _ -> Fail.raise_bad_request "Invalid body provided"

let failwith_opt msg opt =
  match opt with None -> failwith msg | Some value -> value

let failwith_result opt =
  match opt with Error msg -> failwith msg | Ok value -> value

module Msg = struct
  type t = { msg : string } [@@deriving yojson]

  let ok_string () = { msg = "ok" } |> to_yojson |> Yojson.Safe.to_string

  let msg_string msg = { msg } |> to_yojson |> Yojson.Safe.to_string
end

let with_json :
    ?encode:('a -> Yojson.Safe.t) ->
    (Request.t -> ('a, Fail.Error.t) result Lwt.t) ->
    Request.t ->
    Response.t Lwt.t =
 fun ?encode handler req ->
  let* result =
    Lwt.catch
      (fun () -> handler req)
      (fun exn -> Lwt.return @@ Fail.error_of_exn exn)
  in
  let response =
    match (encode, result) with
    | Some encode, Ok result -> result |> encode |> Yojson.Safe.to_string
    | None, Ok _ -> Msg.ok_string ()
    | _, Error error -> Msg.msg_string @@ Fail.Error.show error
  in
  respond' @@ `String response
