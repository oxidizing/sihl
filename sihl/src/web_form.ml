open Lwt.Syntax
open Sexplib.Std

let log_src = Logs.Src.create "sihl.middleware.formparser"

module Logs = (val Logs.src_log log_src : Logs.LOG)

type data = (string * string list) list [@@deriving sexp, show]

let pp = pp_data

exception Parsed_data_not_found

let key : data Opium.Context.key =
  Opium.Context.Key.create ("form", sexp_of_data)
;;

let find_all req =
  match Opium.Context.find key req.Opium.Request.env with
  | Some all -> all
  | None ->
    Logs.err (fun m -> m "Could not find parsed data");
    Logs.info (fun m -> m "Have you applied the data parser middleware?");
    raise Parsed_data_not_found
;;

let find key req =
  let result =
    List.find_opt (fun (k, _) -> String.equal k key) (find_all req)
    |> Option.map snd
  in
  let result =
    try Some (Option.map List.hd result) with
    | _ -> None
  in
  Option.join result
;;

let consume req k =
  let urlencoded = find_all req in
  let value = find k req in
  let updated =
    List.filter (fun (k_, _) -> not (String.equal k_ k)) urlencoded
  in
  let env = req.Opium.Request.env in
  let env = Opium.Context.add key updated env in
  let req = { req with env } in
  req, value
;;

let middleware =
  let filter handler req =
    match req.Opium.Request.meth with
    | `POST ->
      let content_type =
        try
          req
          |> Opium.Request.header "Content-Type"
          |> Option.map (String.split_on_char ';')
          |> Option.map List.hd
        with
        | _ -> None
      in
      (match content_type with
      | Some "multipart/form-data" ->
        let* multipart = Opium.Request.to_multipart_form_data_exn req in
        let multipart = List.map (fun (k, v) -> k, [ v ]) multipart in
        let env = req.Opium.Request.env in
        let env = Opium.Context.add key multipart env in
        let req = { req with env } in
        handler req
      | Some "application/x-www-form-urlencoded" ->
        let* urlencoded = Opium.Request.to_urlencoded req in
        let env = req.Opium.Request.env in
        let env = Opium.Context.add key urlencoded env in
        let req = { req with env } in
        handler req
      | _ -> handler req)
    | _ ->
      (* While GET requests can have bodies, they don't have any meaning and can
         be ignored. Forms only support POST and GET as action methods. *)
      let env = req.Opium.Request.env in
      let env = Opium.Context.add key [] env in
      let req = { req with env } in
      handler req
  in
  Rock.Middleware.create ~name:"formparser" ~filter
;;
