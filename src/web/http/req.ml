open Base
open Lwt.Syntax

type t = Opium_kernel.Request.t

let key : t Core.Ctx.key = Core.Ctx.create_key ()

let add_to_ctx req ctx = Core.Ctx.add key req ctx

let create_and_add_to_ctx ?(body = "") ?(uri = "/") ctx =
  let req =
    Opium.Std.Request.create
      ~body:(Cohttp_lwt.Body.of_string body)
      (Cohttp_lwt.Request.make (Uri.of_string uri))
  in
  add_to_ctx req ctx

let get_req ctx =
  match Core.Ctx.find key ctx with
  | None -> raise (Http_core.Exception "No HTTP request found in context")
  | Some req -> req

module Query = struct
  type t = (string * string list) list [@@deriving eq, show, yojson]
end

let is_get ctx =
  let req = get_req ctx in
  match Opium_kernel.Rock.Request.meth req with `GET -> true | _ -> false

let get_uri ctx =
  let req = get_req ctx in
  Opium_kernel.Request.uri req

let accepts_html ctx =
  let req = get_req ctx in
  Cohttp.Header.get (Opium.Std.Request.headers req) "Accept"
  |> Option.value_map ~default:false ~f:(fun a ->
         String.is_substring a ~substring:"text/html")

let require_authorization_header ctx =
  let req = get_req ctx in
  match req |> Opium.Std.Request.headers |> Cohttp.Header.get_authorization with
  | None -> Error "No authorization header found"
  | Some token -> Ok token

let cookie_data ctx ~key =
  let req = get_req ctx in
  let cookies =
    req |> Opium_kernel.Request.headers |> Cohttp.Cookie.Cookie_hdr.extract
  in
  cookies
  |> List.find ~f:(fun (k, _) -> String.equal key k)
  |> Option.map ~f:(fun (_, v) -> Uri.pct_decode v)

let get_header ctx key =
  let req = get_req ctx in
  Cohttp.Header.get (Opium.Std.Request.headers req) key

let parse_token ctx =
  (* TODO make this more robust *)
  get_header ctx "authorization"
  |> Option.map ~f:(String.split ~on:' ')
  |> Option.bind ~f:List.tl |> Option.bind ~f:List.hd

let find_in_query key query =
  query
  |> List.find ~f:(fun (k, _) -> String.equal k key)
  |> Option.map ~f:(fun (_, r) -> r)
  |> Option.bind ~f:List.hd

let get_query_string ctx =
  let req = get_req ctx in
  req |> Opium.Std.Request.uri |> Uri.query

let query_opt ctx key = ctx |> get_query_string |> find_in_query key

let query ctx key =
  match query_opt ctx key with
  | None -> Error (Printf.sprintf "Please provide a key '%s'" key)
  | Some value -> Ok value

let query2_opt ctx key1 key2 = (query_opt ctx key1, query_opt ctx key2)

let query2 ctx key1 key2 = (query ctx key1, query ctx key2)

let query3_opt ctx key1 key2 key3 =
  (query_opt ctx key1, query_opt ctx key2, query_opt ctx key3)

let query3 ctx key1 key2 key3 = (query ctx key1, query ctx key2, query ctx key3)

let urlencoded_list ?body ctx =
  let req = get_req ctx in
  let* body =
    match body with
    | Some body -> Lwt.return body
    | None -> req |> Opium.Std.Request.body |> Opium.Std.Body.to_string
  in
  body |> Uri.pct_decode |> Uri.query_of_encoded |> Lwt.return

let urlencoded ?body ctx key =
  let req = get_req ctx in
  (* we need to be able to pass in the body
     because Opium.Std.Request.body drains
     the body stream from the request *)
  let* body =
    match body with
    | Some body -> Lwt.return body
    | None -> req |> Opium.Std.Request.body |> Opium.Std.Body.to_string
  in
  match body |> Uri.pct_decode |> Uri.query_of_encoded |> find_in_query key with
  | None -> Lwt.return None
  | Some value -> Lwt.return @@ Some value

let urlencoded2 ctx key1 key2 =
  let* body =
    ctx |> get_req |> Opium.Std.Request.body |> Opium.Std.Body.to_string
  in
  let* value1 = urlencoded ~body ctx key1 in
  let* value2 = urlencoded ~body ctx key2 in
  Lwt.return @@ Option.both value1 value2

let urlencoded3 ctx key1 key2 key3 =
  let* body =
    ctx |> get_req |> Opium.Std.Request.body |> Opium.Std.Body.to_string
  in
  let* value1 = urlencoded ~body ctx key1 in
  let* value2 = urlencoded ~body ctx key2 in
  let* value3 = urlencoded ~body ctx key3 in
  match (value1, value2, value3) with
  | Some value1, Some value2, Some value3 ->
      Lwt.return @@ Some (value1, value2, value3)
  | _ -> Lwt.return None

let urlencoded4 ctx key1 key2 key3 key4 =
  let* body =
    ctx |> get_req |> Opium.Std.Request.body |> Opium.Std.Body.to_string
  in
  let* value1 = urlencoded ~body ctx key1 in
  let* value2 = urlencoded ~body ctx key2 in
  let* value3 = urlencoded ~body ctx key3 in
  let* value4 = urlencoded ~body ctx key4 in
  match (value1, value2, value3, value4) with
  | Some value1, Some value2, Some value3, Some value4 ->
      Lwt.return @@ Some (value1, value2, value3, value4)
  | _ -> Lwt.return None

let urlencoded5 ctx key1 key2 key3 key4 key5 =
  let* body =
    ctx |> get_req |> Opium.Std.Request.body |> Opium.Std.Body.to_string
  in
  let* value1 = urlencoded ~body ctx key1 in
  let* value2 = urlencoded ~body ctx key2 in
  let* value3 = urlencoded ~body ctx key3 in
  let* value4 = urlencoded ~body ctx key4 in
  let* value5 = urlencoded ~body ctx key5 in
  match (value1, value2, value3, value4, value5) with
  | Some value1, Some value2, Some value3, Some value4, Some value5 ->
      Lwt.return @@ Some (value1, value2, value3, value4, value5)
  | _ -> Lwt.return None

let param ctx key =
  let req = get_req ctx in
  Option.try_with (fun () -> Opium.Std.param req key)

let param2 ctx key1 key2 = Option.both (param ctx key1) (param ctx key2)

let param3 ctx key1 key2 key3 =
  match (param ctx key1, param ctx key2, param ctx key3) with
  | Some p1, Some p2, Some p3 -> Some (p1, p2, p3)
  | _ -> None

let param4 ctx key1 key2 key3 key4 =
  match (param ctx key1, param ctx key2, param ctx key3, param ctx key4) with
  | Some p1, Some p2, Some p3, Some p4 -> Some (p1, p2, p3, p4)
  | _ -> None

let param5 ctx key1 key2 key3 key4 key5 =
  match
    ( param ctx key1,
      param ctx key2,
      param ctx key3,
      param ctx key4,
      param ctx key5 )
  with
  | Some p1, Some p2, Some p3, Some p4, Some p5 -> Some (p1, p2, p3, p4, p5)
  | _ -> None

let require_body ctx decode =
  let* body =
    ctx |> get_req |> Opium.Std.Request.body |> Cohttp_lwt.Body.to_string
  in
  body |> Utils.Json.parse |> Result.bind ~f:decode |> Lwt.return
