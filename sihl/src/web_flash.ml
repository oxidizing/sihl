let log_src = Logs.Src.create "sihl.middleware.flash"

module Logs = (val Logs.src_log log_src : Logs.LOG)

module Flash = struct
  type t =
    { alert : string option
    ; notice : string option
    ; custom : string option
    }

  let empty = { alert = None; notice = None; custom = None }

  let of_yojson json =
    let open Yojson.Safe.Util in
    try
      let alert = json |> member "alert" |> to_string_option in
      let notice = json |> member "notice" |> to_string_option in
      let custom = json |> member "custom" |> to_string_option in
      Some { alert; notice; custom }
    with
    | _ -> None
  ;;

  let to_yojson { alert; notice; custom } =
    let alert =
      alert
      |> Option.map (fun alert -> `String alert)
      |> Option.value ~default:`Null
    in
    let notice =
      notice
      |> Option.map (fun notice -> `String notice)
      |> Option.value ~default:`Null
    in
    let custom =
      custom
      |> Option.map (fun custom -> `String custom)
      |> Option.value ~default:`Null
    in
    `Assoc [ "alert", alert; "notice", notice; "custom", custom ]
  ;;

  let of_json json =
    try of_yojson (Yojson.Safe.from_string json) with
    | _ -> None
  ;;

  let to_json flash = flash |> to_yojson |> Yojson.Safe.to_string

  let to_sexp flash =
    let open Sexplib0.Sexp_conv in
    let open Sexplib0.Sexp in
    List
      [ List [ Atom "alert"; sexp_of_option sexp_of_string flash.alert ]
      ; List [ Atom "notice"; sexp_of_option sexp_of_string flash.notice ]
      ; List [ Atom "custom"; sexp_of_option sexp_of_string flash.custom ]
      ]
  ;;
end

exception Flash_not_found

module Env = struct
  let key : Flash.t Opium.Context.key =
    Opium.Context.Key.create ("flash", Flash.to_sexp)
  ;;
end

let find req =
  (* Raising an exception is ok since we assume that before find can be called
     the middleware has been passed *)
  try Opium.Context.find_exn Env.key req.Opium.Request.env with
  | _ ->
    Logs.err (fun m -> m "No flash storage found");
    Logs.info (fun m ->
        m "Have you applied the flash middleware for this route?");
    raise Flash_not_found
;;

let find_alert req = (find req).alert
let find_notice req = (find req).notice
let find_custom req = (find req).custom

let set_alert alert resp =
  let flash = Opium.Context.find Env.key resp.Opium.Response.env in
  let flash =
    match flash with
    | None -> Flash.{ empty with alert }
    | Some flash -> Flash.{ flash with alert }
  in
  let env = resp.Opium.Response.env in
  let env = Opium.Context.add Env.key flash env in
  { resp with env }
;;

let set_notice notice resp =
  let flash = Opium.Context.find Env.key resp.Opium.Response.env in
  let flash =
    match flash with
    | None -> Flash.{ empty with notice }
    | Some flash -> Flash.{ flash with notice }
  in
  let env = resp.Opium.Response.env in
  let env = Opium.Context.add Env.key flash env in
  { resp with env }
;;

let set_custom custom resp =
  let flash = Opium.Context.find Env.key resp.Opium.Response.env in
  let flash =
    match flash with
    | None -> Flash.{ empty with custom }
    | Some flash -> Flash.{ flash with custom }
  in
  let env = resp.Opium.Response.env in
  let env = Opium.Context.add Env.key flash env in
  { resp with env }
;;

let decode_flash cookie_key req =
  match Opium.Request.cookie cookie_key req with
  | None -> Flash.empty
  | Some cookie_value ->
    (match Flash.of_json cookie_value with
    | None ->
      Logs.err (fun m ->
          m
            "Failed to parse value found in flash cookie '%s': '%s'"
            cookie_key
            cookie_value);
      Logs.info (fun m ->
          m
            "Maybe the cookie key '%s' collides with a cookie issued by \
             someone else. Try to change the cookie key."
            cookie_key);
      Flash.empty
    | Some flash -> flash)
;;

let persist_flash cookie_key resp =
  let flash = Opium.Context.find Env.key resp.Opium.Response.env in
  match flash with
  | None -> (* No need to touch the flash cookie *) resp
  | Some flash ->
    (* The flash changed, we need to persist the new flash in the cookie *)
    let cookie_value = Flash.to_json flash in
    let cookie = cookie_key, cookie_value in
    let resp = Opium.Response.add_cookie_or_replace cookie resp in
    resp
;;

let middleware ?(cookie_key = "_flash") () =
  let open Lwt.Syntax in
  let filter handler req =
    let flash = decode_flash cookie_key req in
    let env = req.Opium.Request.env in
    let env = Opium.Context.add Env.key flash env in
    let req = { req with env } in
    let* resp = handler req in
    Lwt.return @@ persist_flash cookie_key resp
  in
  Rock.Middleware.create ~name:"flash" ~filter
;;
