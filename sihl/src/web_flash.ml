let log_src = Logs.Src.create "sihl.middleware.flash"

module Logs = (val Logs.src_log log_src : Logs.LOG)

module Flash = struct
  open Sexplib.Conv

  type t =
    { alert : string option
    ; notice : string option
    ; custom : (string * string) list
    }
  [@@deriving yojson, sexp]

  let empty = { alert = None; notice = None; custom = [] }

  let is_empty (flash : t) : bool =
    match flash.alert, flash.notice, flash.custom with
    | None, None, [] -> true
    | _ -> false
  ;;

  let equals f1 f2 =
    Option.equal String.equal f1.alert f2.alert
    && Option.equal String.equal f1.notice f2.notice
    && CCList.equal (CCPair.equal String.equal String.equal) f1.custom f2.custom
  ;;

  let of_json (json : string) : t option =
    try Some (of_yojson (Yojson.Safe.from_string json) |> Result.get_ok) with
    | _ -> None
  ;;

  let to_json (flash : t) : string = flash |> to_yojson |> Yojson.Safe.to_string
end

module Env = struct
  let key : Flash.t Opium.Context.key =
    Opium.Context.Key.create ("flash", Flash.sexp_of_t)
  ;;
end

let find' req = Opium.Context.find Env.key req.Opium.Request.env
let find_alert req = Option.bind (find' req) (fun flash -> flash.alert)
let find_notice req = Option.bind (find' req) (fun flash -> flash.notice)

let find key req =
  Option.bind (find' req) (fun flash ->
      flash.custom
      |> List.find_opt (fun (k, _) -> String.equal key k)
      |> Option.map snd)
;;

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

let set values resp =
  let flash = Opium.Context.find Env.key resp.Opium.Response.env in
  let flash =
    match flash with
    | None -> Flash.{ empty with custom = values }
    | Some flash -> Flash.{ flash with custom = values }
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

let persist_flash old_flash cookie_key resp =
  let flash = Opium.Context.find Env.key resp.Opium.Response.env in
  match flash with
  | None ->
    if Flash.is_empty old_flash
    then (* Flash was not touched, don't set cookie *)
      resp
    else (* Remove flash cookie *)
      Opium.Response.remove_cookie cookie_key resp
  | Some flash ->
    if Flash.equals old_flash flash
    then (* Flash was not touched, don't set cookie *)
      resp
    else if Flash.is_empty flash
    then (* Remove flash cookie *)
      Opium.Response.remove_cookie cookie_key resp
    else (
      (* Flash was changed and is not empty, set cookie *)
      let cookie_value = Flash.to_json flash in
      let cookie = cookie_key, cookie_value in
      let resp = Opium.Response.add_cookie_or_replace cookie resp in
      resp)
;;

let middleware ?(cookie_key = "_flash") () =
  let open Lwt.Syntax in
  let filter handler req =
    let flash = decode_flash cookie_key req in
    let env = req.Opium.Request.env in
    let env = Opium.Context.add Env.key flash env in
    let req = { req with env } in
    let* resp = handler req in
    Lwt.return @@ persist_flash flash cookie_key resp
  in
  Rock.Middleware.create ~name:"flash" ~filter
;;
