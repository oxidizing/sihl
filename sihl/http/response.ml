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
include Opium_kernel.Rock.Response

(* Encoders *)

let redirect_to
    ?(env = Opium_kernel.Hmap.empty)
    ?(headers = Cohttp.Header.init ())
    location
  =
  let headers = Cohttp.Header.add headers "Location" location in
  { env; code = `Moved_permanently; headers; body = Cohttp_lwt.Body.empty }
;;

let of_plain_text
    ?(env = Opium_kernel.Hmap.empty)
    ?(headers = Cohttp.Header.init ())
    ?(code = `OK)
    text
  =
  let body = Cohttp_lwt.Body.of_string text in
  { env; code; headers; body }
;;

let of_json
    ?(env = Opium_kernel.Hmap.empty)
    ?(headers = Cohttp.Header.init ())
    ?(code = `OK)
    json
  =
  let headers =
    Cohttp.Header.add_unless_exists headers "Content-Type" "application/json"
  in
  let body = Cohttp_lwt.Body.of_string (Yojson.Safe.to_string json) in
  { env; code; headers; body }
;;

let of_file ?(headers = Cohttp.Header.init ()) file_path =
  let* response_body = Cohttp_lwt_unix.Server.respond_file ~headers ~fname:file_path () in
  Lwt.return @@ of_response_body response_body
;;

(* Decoders *)

let to_json_exn t =
  let open Lwt.Syntax in
  let* body = Cohttp_lwt.Body.to_string t.body in
  Lwt.return @@ Yojson.Safe.from_string body
;;

let to_json t =
  let open Lwt.Syntax in
  Lwt.catch
    (fun () ->
      let+ json = to_json_exn t in
      Some json)
    (function
      | _ -> Lwt.return None)
;;

let to_plain_text t = Cohttp_lwt.Body.to_string t.body

(* Setters & Getters *)

let status response = Cohttp.Code.code_of_status response.code

let set_status status response =
  { response with code = Cohttp.Code.status_of_code status }
;;

let header k t = Cohttp.Header.get t.headers k
let headers k t = Cohttp.Header.get_multi t.headers k

let add_header (k, v) t =
  (* TODO [jerben] make sure this appends values and doesn't replace *)
  { t with headers = Cohttp.Header.add t.headers k v }
;;

let add_header_or_replace (k, v) t = { t with headers = Cohttp.Header.add t.headers k v }

let add_header_unless_exists (k, v) t =
  { t with headers = Cohttp.Header.add_unless_exists t.headers k v }
;;

let add_headers headers t =
  (* TODO [jerben] make sure this appends values and doesn't replace *)
  { t with headers = Cohttp.Header.add_list t.headers headers }
;;

let add_headers_or_replace headers t =
  { t with headers = Cohttp.Header.add_list t.headers headers }
;;

let add_headers_unless_exists headers t =
  List.fold_left (fun t (k, v) -> add_header_unless_exists (k, v) t) t headers
;;

let remove_header s t = { t with headers = Cohttp.Header.remove t.headers s }
let content_type t = header "content-type" t
let set_content_type s t = add_header_or_replace ("content-type", s) t
let etag t = header "etag" t
let set_etag s t = add_header_or_replace ("etag", s) t
let location t = header "location" t
let set_location s t = add_header_or_replace ("location", s) t
let cache_control t = header "cache-control" t
let set_cache_control s t = add_header_or_replace ("cache-control", s) t

(* Cookies *)

let cookie ?signed_with key t =
  let cookie_opt =
    headers "Set-Cookie" t
    |> List.map (fun v -> Cookie.of_set_cookie_header ?signed_with ("Set-Cookie", v))
    |> List.find_opt (function
           | Some Cookie.{ value = k, _; _ } when String.equal k key -> true
           | _ -> false)
  in
  Option.bind cookie_opt (fun x -> x)
;;

let cookies ?signed_with t =
  headers "set-cookie" t
  |> List.map (fun v -> Cookie.of_set_cookie_header ?signed_with ("set-cookie", v))
  |> List.filter_map (fun x -> x)
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

let add_cookie ?sign_with ?expires ?scope ?same_site ?secure ?http_only value t =
  let cookie_header =
    Cookie.make ?sign_with ?expires ?scope ?same_site ?secure ?http_only value
    |> Cookie.to_set_cookie_header
  in
  let headers =
    replace_or_add_to_list
      ~f:(fun (k, v) _ ->
        match k, v with
        | k, v
          when String.equal (String.lowercase_ascii k) "set-cookie"
               && String.length v > String.length (fst value)
               && String.equal
                    (StringLabels.sub v ~pos:0 ~len:(String.length (fst value)))
                    (fst value) -> true
        | _ -> false)
      cookie_header
      (Cohttp.Header.to_list t.headers)
  in
  { t with headers = Cohttp.Header.of_list headers }
;;

let add_cookie_unless_exists
    ?sign_with
    ?expires
    ?scope
    ?same_site
    ?secure
    ?http_only
    (k, v)
    t
  =
  let cookies = cookies t in
  if List.exists (fun Cookie.{ value = cookie, _; _ } -> String.equal cookie k) cookies
  then t
  else add_cookie ?sign_with ?expires ?scope ?same_site ?secure ?http_only (k, v) t
;;

let remove_cookie key t = add_cookie ~expires:(`Max_age 0L) (key, "") t
