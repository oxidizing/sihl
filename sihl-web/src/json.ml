let log_src = Logs.Src.create "sihl.middleware.jsonparser"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let key : Yojson.Safe.t Opium.Context.key =
  Opium.Context.Key.create
    ( "json"
    , fun json -> json |> Yojson.Safe.to_string |> Sexplib.Std.sexp_of_string )
;;

exception Json_body_not_found

let find req =
  try Opium.Context.find_exn key req.Opium.Request.env with
  | _ ->
    Logs.err (fun m -> m "No JSON body found");
    Logs.info (fun m ->
        m "Have you applied the JSON parser middleware for this route?");
    raise Json_body_not_found
;;

let find_opt req =
  try Some (find req) with
  | _ -> None
;;

let set token req =
  let env = req.Opium.Request.env in
  let env = Opium.Context.add key token env in
  { req with env }
;;

let middleware =
  let open Lwt.Syntax in
  let filter handler req =
    match req.Opium.Request.meth with
    (* While GET requests can have bodies, they don't have any meaning and can
       be ignored. Forms only support POST and GET as action methods. *)
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
      | Some "application/json" ->
        let* json_body = Opium.Request.to_json req in
        (match json_body with
        | Some json ->
          let req = set json req in
          handler req
        | None ->
          let response_body =
            Format.sprintf {|"{"errors": ["Invalid JSON provided"]"}"|}
          in
          Opium.Response.of_plain_text response_body
          |> Opium.Response.set_status `Bad_request
          |> Lwt.return)
      | _ -> handler req)
    | _ -> handler req
  in
  Rock.Middleware.create ~name:"jsonparser" ~filter
;;
