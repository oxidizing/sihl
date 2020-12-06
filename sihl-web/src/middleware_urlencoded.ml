open Lwt.Syntax
open Sexplib.Std

let log_src = Logs.Src.create "sihl.middleware.urlencoded"

module Logs = (val Logs.src_log log_src : Logs.LOG)

type urlencoded = (string * string list) list [@@deriving sexp]

exception Urlencoded_not_found

let key : urlencoded Opium.Context.key =
  Opium.Context.Key.create ("urlencoded", sexp_of_urlencoded)
;;

let find_all req =
  match Opium.Context.find key req.Opium.Request.env with
  | Some all -> all
  | None ->
    Logs.err (fun m -> m "No parsed urlencoded body found");
    Logs.info (fun m -> m "Have you applied the urlencoded middleware?");
    raise Urlencoded_not_found
;;

let find key req =
  let result =
    List.find_opt (fun (k, _) -> String.equal k key) (find_all req) |> Option.map snd
  in
  let result =
    try Some (Option.map List.hd result) with
    | _ -> None
  in
  Option.join result
;;

(** [consume req key] returns the value of the parsed urlencoded body for the key [key]
    and a request with an update context where the parsed urlencoded is missing the key
    [key]. The urlencoded value is returned and removed from the context, it is consumed.
    **)
let consume req k =
  let urlencoded = find_all req in
  let value = find k req in
  let updated = List.filter (fun (k_, _) -> not (String.equal k_ k)) urlencoded in
  let env = req.Opium.Request.env in
  let env = Opium.Context.add key updated env in
  let req = { req with env } in
  req, value
;;

let m () =
  let filter handler req =
    let* urlencoded = Sihl_type.Http_request.to_urlencoded req in
    let env = req.Opium.Request.env in
    let env = Opium.Context.add key urlencoded env in
    let req = { req with env } in
    handler req
  in
  Rock.Middleware.create ~name:"urlencoded" ~filter
;;
