open Lwt.Syntax
open Sexplib.Std

let log_src = Logs.Src.create "sihl.middleware.urlencoded"

module Logs = (val Logs.src_log log_src : Logs.LOG)

type urlencoded = (string * string list) list [@@deriving sexp]

let key : urlencoded Opium_kernel.Hmap.key =
  Opium_kernel.Hmap.Key.create ("urlencoded", sexp_of_urlencoded)
;;

let find_all req = Opium_kernel.Hmap.find_exn key (Opium_kernel.Request.env req)
let find req key = List.find_opt (fun (k, _) -> String.equal k key) (find_all req)

(** [consume req key] returns the value of the parsed urlencoded body for the key [key]
    and a request with an update context where the parsed urlencoded is missing the key
    [key]. The urlencoded value is returned and removed from the context, it is consumed.
    **)
let consume req k =
  let urlencoded = find_all req in
  let value = find req k in
  let updated = List.filter (fun (k_, _) -> not (String.equal k_ k)) urlencoded in
  let env = Opium_kernel.Request.env req in
  let env = Opium_kernel.Hmap.add key updated env in
  let req = { req with env } in
  req, value
;;

let m () =
  let filter handler req =
    let* urlencoded = Sihl_type.Http_request.to_urlencoded req in
    let env = Opium_kernel.Request.env req in
    let env = Opium_kernel.Hmap.add key urlencoded env in
    let req = { req with env } in
    handler req
  in
  Opium_kernel.Rock.Middleware.create ~name:"urlencoded" ~filter
;;
