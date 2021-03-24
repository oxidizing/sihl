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
    | None -> Flash.{ alert = Some alert; notice = None; custom = [] }
    | Some flash -> Flash.{ flash with alert = Some alert }
  in
  let env = resp.Opium.Response.env in
  let env = Opium.Context.add Env.key flash env in
  { resp with env }
;;

let set_notice notice resp =
  let flash = Opium.Context.find Env.key resp.Opium.Response.env in
  let flash =
    match flash with
    | None -> Flash.{ alert = None; notice = Some notice; custom = [] }
    | Some flash -> Flash.{ flash with notice = Some notice }
  in
  let env = resp.Opium.Response.env in
  let env = Opium.Context.add Env.key flash env in
  { resp with env }
;;

let set values resp =
  let flash = Opium.Context.find Env.key resp.Opium.Response.env in
  let flash =
    match flash with
    | None -> Flash.{ alert = None; notice = None; custom = values }
    | Some flash -> Flash.{ flash with custom = values }
  in
  let env = resp.Opium.Response.env in
  let env = Opium.Context.add Env.key flash env in
  { resp with env }
;;

type decode_status =
  | No_cookie_found
  | Parse_error
  | Found of Flash.t

let decode_flash cookie_key req =
  match Opium.Request.cookie cookie_key req with
  | None -> No_cookie_found
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
      Parse_error
    | Some flash -> Found flash)
;;

let persist_flash ?old_flash ?(delete_if_not_set = false) cookie_key resp =
  let flash = Opium.Context.find Env.key resp.Opium.Response.env in
  match flash with
  (* No flash was set in handler *)
  | None ->
    if delete_if_not_set
    then
      (* Remove flash cookie *)
      Opium.Response.add_cookie_or_replace
        ~expires:(`Max_age Int64.zero)
        ~scope:(Uri.of_string "/")
        (cookie_key, "")
        resp
    else resp
  (* Flash was set in handler *)
  | Some flash ->
    (match old_flash with
    | Some old_flash ->
      if Flash.equals old_flash flash
      then (* Same flash value, don't set cookie *)
        resp
      else (
        (* Flash was changed and is different than old flash, set cookie *)
        let cookie_value = Flash.to_json flash in
        let cookie = cookie_key, cookie_value in
        let resp =
          Opium.Response.add_cookie_or_replace
            ~scope:(Uri.of_string "/")
            cookie
            resp
        in
        resp)
    | None ->
      (* Flash was changed and old flash is empty, set cookie *)
      let cookie_value = Flash.to_json flash in
      let cookie = cookie_key, cookie_value in
      let resp =
        Opium.Response.add_cookie_or_replace
          ~scope:(Uri.of_string "/")
          cookie
          resp
      in
      resp)
;;

let middleware ?(cookie_key = "_flash") () =
  let open Lwt.Syntax in
  let filter handler req =
    match decode_flash cookie_key req with
    | No_cookie_found ->
      let* resp = handler req in
      Lwt.return @@ persist_flash cookie_key resp
    | Parse_error ->
      let* resp = handler req in
      Lwt.return @@ persist_flash ~delete_if_not_set:true cookie_key resp
    | Found flash ->
      let env = req.Opium.Request.env in
      let env = Opium.Context.add Env.key flash env in
      let req = { req with env } in
      let* resp = handler req in
      Lwt.return
      @@ persist_flash ~delete_if_not_set:true ~old_flash:flash cookie_key resp
  in
  Rock.Middleware.create ~name:"flash" ~filter
;;
