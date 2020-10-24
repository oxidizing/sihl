(* This module is based on the reworked API of Opium.

   MIT License

   Copyright (c) 2019 Rudi Grinberg

   Permission is hereby granted, free of charge, to any person obtaining a copy of this
   software and associated documentation files (the "Software"), to deal in the Software
   without restriction, including without limitation the rights to use, copy, modify,
   merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
   permit persons to whom the Software is furnished to do so, subject to the following
   conditions:

   The above copyright notice and this permission notice shall be included in all copies
   or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
   INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
   PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
   HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
   CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
   THE USE OR OTHER DEALINGS IN THE SOFTWARE. *)

open Lwt.Syntax
include Opium_kernel.Rock.Request

let to_plain_text t = t |> Opium.Std.Request.body |> Opium.Std.Body.to_string

let to_json t =
  let* body = t |> Opium.Std.Request.body |> Opium.Std.Body.to_string in
  try Lwt.return (Some (Yojson.Safe.from_string body)) with
  | _ -> Lwt.return None
;;

let to_json_exn t =
  let* json = to_json t in
  Lwt.return (Option.get json)
;;

let to_urlencoded t =
  let* body = t |> Opium.Std.Request.body |> Opium.Std.Body.to_string in
  Lwt.return (Uri.query_of_encoded body)
;;

let to_multipart_form_data_exn
    ?(callback = fun ~name:_ ~filename:_ _line -> Lwt.return_unit)
    t
  =
  let stream = t |> Opium.Std.Request.body |> Opium.Std.Body.to_stream in
  Multipart_form_data.parse ~stream ~content_type:"multipart/form-data" ~callback
;;

let to_multipart_form_data
    ?(callback = fun ~name:_ ~filename:_ _line -> Lwt.return_unit)
    t
  =
  Lwt.catch
    (fun () ->
      let* parsed = to_multipart_form_data_exn ~callback t in
      Lwt.return (Some parsed))
    (fun _ -> Lwt.return None)
;;

let header s t = Cohttp.Header.get (Cohttp.Request.headers t.request) s
let headers s t = Cohttp.Header.get_multi (Cohttp.Request.headers t.request) s

let add_header (k, v) t =
  (* TODO [jerben] make sure this appends values and doesn't replace *)
  let request =
    { t.request with headers = Cohttp.Header.add (Cohttp.Request.headers t.request) k v }
  in
  { t with request }
;;

let add_header_or_replace (k, v) t =
  let request =
    { t.request with headers = Cohttp.Header.add (Cohttp.Request.headers t.request) k v }
  in
  { t with request }
;;

let add_header_unless_exists (k, v) t =
  let request =
    { t.request with
      headers = Cohttp.Header.add_unless_exists (Cohttp.Request.headers t.request) k v
    }
  in
  { t with request }
;;

let add_headers headers t =
  (* TODO [jerben] make sure this appends values and doesn't replace *)
  let request =
    { t.request with
      headers = Cohttp.Header.add_list (Cohttp.Request.headers t.request) headers
    }
  in
  { t with request }
;;

let add_headers_or_replace headers t =
  let request =
    { t.request with
      headers = Cohttp.Header.add_list (Cohttp.Request.headers t.request) headers
    }
  in
  { t with request }
;;

let add_headers_unless_exists headers t =
  List.fold_left (fun t (k, v) -> add_header_unless_exists (k, v) t) t headers
;;

let remove_header s t =
  let request =
    { t.request with headers = Cohttp.Header.remove (Cohttp.Request.headers t.request) s }
  in
  { t with request }
;;

let cookie ?signed_with cookie t =
  Cookie.cookie_of_headers ?signed_with cookie (t.request.headers |> Cohttp.Header.to_list)
  |> Option.map snd
;;

let cookies ?signed_with t =
  Cookie.cookies_of_headers ?signed_with (t.request.headers |> Cohttp.Header.to_list)
;;

let replace_or_add_to_list ~f to_add l =
  let found = ref false in
  let rec aux acc l =
    match l with
    | [] -> if not !found then to_add :: acc |> List.rev else List.rev acc
    | el :: rest ->
      if f el to_add
      then (
        found := true;
        aux (to_add :: acc) rest)
      else aux (el :: acc) rest
  in
  aux [] l
;;

let add_cookie ?sign_with (k, v) t =
  let cookies = cookies t in
  let cookies =
    replace_or_add_to_list
      ~f:(fun (k2, _v2) _ -> String.equal k k2)
      ( k
      , match sign_with with
        | Some signer -> Cookie.Signer.sign signer v
        | None -> v )
      cookies
  in
  let cookie_header = cookies |> List.map Cookie.make |> Cookie.to_cookie_header in
  add_header_or_replace cookie_header t
;;

let add_cookie_unless_exists ?sign_with (k, v) t =
  let cookies = cookies t in
  if List.exists (fun (k2, _v2) -> String.equal k2 k) cookies
  then t
  else add_cookie ?sign_with (k, v) t
;;

let remove_cookie key t =
  let cookie_header =
    cookies t
    |> List.filter (fun (k, _) -> not (String.equal k key))
    |> List.map Cookie.make
    |> Cookie.to_cookie_header
  in
  add_header_or_replace cookie_header t
;;

let content_type t = header "content-type" t
let set_content_type s t = add_header_or_replace ("content-type", s) t

let find_in_query key query =
  query
  |> List.find_opt (fun (k, _) -> k = key)
  |> Option.map (fun (_, r) -> r)
  |> fun opt ->
  Option.bind opt (fun x ->
      try Some (List.hd x) with
      | Not_found -> None)
;;

let urlencoded key t =
  let open Lwt.Syntax in
  let* query = to_urlencoded t in
  Lwt.return @@ find_in_query key query
;;

let urlencoded_exn key t =
  let open Lwt.Syntax in
  let+ o = urlencoded key t in
  Option.get o
;;

let query_list t = t.request |> Cohttp.Request.uri |> Uri.query
let query key t = query_list t |> find_in_query key
let query_exn key t = query key t |> Option.get

let key : string Opium_kernel.Hmap.key =
  Opium_kernel.Hmap.Key.create ("id", Sexplib.Std.sexp_of_string)
;;

let find req = Opium_kernel.Hmap.find_exn key (Opium_kernel.Request.env req)

let find_opt req =
  try Some (find req) with
  | _ -> None
;;

let to_ctx req =
  match find_opt req with
  | Some id -> Core.Ctx.create ~id ()
  | None -> Core.Ctx.create ()
;;

let is_get req =
  match Opium_kernel.Rock.Request.meth req with
  | `GET -> true
  | _ -> false
;;

let contains substring string =
  let re = Str.regexp_string string in
  try
    ignore (Str.search_forward re substring 0);
    true
  with
  | Not_found -> false
;;

let accepts_html req =
  Cohttp.Header.get (Opium.Std.Request.headers req) "Accept"
  |> Option.map (contains "text/html")
  |> Option.value ~default:false
;;

let authorization_token t =
  let ( let* ) = Option.bind in
  (* TODO [jerben] make this more robust *)
  let* header = header "authorization" t in
  match String.split_on_char ' ' header with
  | [ _; token ] -> Some token
  | _ -> None
;;

let param req key =
  try Some (Opium.Std.param req key) with
  | _ -> None
;;

let params req key1 key2 =
  match param req key1, param req key2 with
  | Some a, Some b -> Some (a, b)
  | _ -> None
;;

let params3 req key1 key2 key3 =
  match param req key1, param req key2, param req key3 with
  | Some p1, Some p2, Some p3 -> Some (p1, p2, p3)
  | _ -> None
;;

let params4 req key1 key2 key3 key4 =
  match param req key1, param req key2, param req key3, param req key4 with
  | Some p1, Some p2, Some p3, Some p4 -> Some (p1, p2, p3, p4)
  | _ -> None
;;

let params5 req key1 key2 key3 key4 key5 =
  match
    param req key1, param req key2, param req key3, param req key4, param req key5
  with
  | Some p1, Some p2, Some p3, Some p4, Some p5 -> Some (p1, p2, p3, p4, p5)
  | _ -> None
;;

let make
    ?(body = Opium.Std.Body.empty)
    ?(env = Opium_kernel.Hmap.empty)
    ?(headers = Cohttp.Header.init ())
    uri
    meth
  =
  let uri = Uri.of_string uri in
  let request = Cohttp_lwt_unix.Request.make ~meth ~headers uri in
  { body; env; request }
;;

let get
    ?(body = Opium.Std.Body.empty)
    ?(env = Opium_kernel.Hmap.empty)
    ?(headers = Cohttp.Header.init ())
    uri
  =
  let uri = Uri.of_string uri in
  let request = Cohttp_lwt_unix.Request.make ~meth:`GET ~headers uri in
  { body; env; request }
;;

let post
    ?(body = Opium.Std.Body.empty)
    ?(env = Opium_kernel.Hmap.empty)
    ?(headers = Cohttp.Header.init ())
    uri
  =
  let uri = Uri.of_string uri in
  let request = Cohttp_lwt_unix.Request.make ~meth:`POST ~headers uri in
  { body; env; request }
;;

let put
    ?(body = Opium.Std.Body.empty)
    ?(env = Opium_kernel.Hmap.empty)
    ?(headers = Cohttp.Header.init ())
    uri
  =
  let uri = Uri.of_string uri in
  let request = Cohttp_lwt_unix.Request.make ~meth:`PUT ~headers uri in
  { body; env; request }
;;

let delete
    ?(body = Opium.Std.Body.empty)
    ?(env = Opium_kernel.Hmap.empty)
    ?(headers = Cohttp.Header.init ())
    uri
  =
  let uri = Uri.of_string uri in
  let request = Cohttp_lwt_unix.Request.make ~meth:`DELETE ~headers uri in
  { body; env; request }
;;

let of_plain_text
    ?body
    ?(env = Opium_kernel.Hmap.empty)
    ?(headers = Cohttp.Header.init ())
    uri
    meth
  =
  let uri = Uri.of_string uri in
  let body =
    body
    |> Option.map Cohttp_lwt.Body.of_string
    |> Option.value ~default:Opium.Std.Body.empty
  in
  let request = Cohttp_lwt_unix.Request.make ~meth ~headers uri in
  let request = { body; env; request } in
  add_header ("content-type", "text/plain") request
;;

let of_json
    ?body
    ?(env = Opium_kernel.Hmap.empty)
    ?(headers = Cohttp.Header.init ())
    uri
    meth
  =
  let uri = Uri.of_string uri in
  let body =
    body
    |> Option.map Yojson.Safe.to_string
    |> Option.map Cohttp_lwt.Body.of_string
    |> Option.value ~default:Opium.Std.Body.empty
  in
  let request = Cohttp_lwt_unix.Request.make ~meth ~headers uri in
  let request = { body; env; request } in
  add_header ("content-type", "application/json") request
;;

let of_urlencoded
    ?(body = [])
    ?(env = Opium_kernel.Hmap.empty)
    ?(headers = Cohttp.Header.init ())
    uri
    meth
  =
  let uri = Uri.of_string uri in
  let body = body |> Uri.encoded_of_query |> Cohttp_lwt.Body.of_string in
  let request = Cohttp_lwt_unix.Request.make ~meth ~headers uri in
  { body; env; request }
;;
