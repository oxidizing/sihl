let log_src = Logs.Src.create "sihl.middleware.flash"

module Logs = (val Logs.src_log log_src : Logs.LOG)

type t =
  { alert : string option
  ; notice : string option
  ; custom : string option
  }

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

exception Flash_not_found

let key_alert : string option Opium.Context.key =
  Opium.Context.Key.create
    ("flash alert", Sexplib.Std.(sexp_of_option sexp_of_string))
;;

let key_notice : string option Opium.Context.key =
  Opium.Context.Key.create
    ("flash notice", Sexplib.Std.(sexp_of_option sexp_of_string))
;;

let key_custom : string option Opium.Context.key =
  Opium.Context.Key.create
    ("flash custom", Sexplib.Std.(sexp_of_option sexp_of_string))
;;

let find_with_key req key =
  (* Raising an exception is ok since we assume that before find can be called
     the middleware has been passed *)
  try Opium.Context.find_exn key req.Opium.Request.env with
  | _ ->
    Logs.err (fun m -> m "No flash storage found");
    Logs.info (fun m ->
        m
          "Have you applied the session and flash middleware for this route? \
           The flash middleware requires the session middleware.");
    raise Flash_not_found
;;

let set_with_key flash res key =
  let env = res.Opium.Response.env in
  let env = Opium.Context.add key flash env in
  { res with env }
;;

let find_alert req = find_with_key req key_alert
let find_notice req = find_with_key req key_notice
let find_custom req = find_with_key req key_custom
let set_alert alert resp = set_with_key alert resp key_alert
let set_notice notice resp = set_with_key notice resp key_notice
let set_custom custom resp = set_with_key custom resp key_custom

let decode_flash flash =
  let parsed =
    try Some (Yojson.Safe.from_string flash) with
    | _ -> None
  in
  match parsed with
  | None ->
    Logs.warn (fun m -> m "Failed to parse flash message %s" flash);
    None, None, None
  | Some parsed ->
    (match of_yojson parsed with
    | None ->
      Logs.warn (fun m -> m "Failed to decode flash message %s" flash);
      None, None, None
    | Some decoded -> decoded.alert, decoded.notice, decoded.custom)
;;

let middleware ?(flash_store_name = "flash.store") () =
  let open Lwt.Syntax in
  let filter handler req =
    let session = Session.find req in
    let* current_flash =
      Sihl_facade.Session.find_value session flash_store_name
    in
    let alert, notice, custom =
      match current_flash with
      | None -> None, None, None
      | Some current_flash -> decode_flash current_flash
    in
    let env = req.Opium.Request.env in
    let env = Opium.Context.add key_alert alert env in
    let env = Opium.Context.add key_notice notice env in
    let env = Opium.Context.add key_custom custom env in
    let req = { req with env } in
    (* User might call set() in handler *)
    let* res = handler req in
    let alert =
      Option.join (Opium.Context.find key_alert res.Opium.Response.env)
    in
    let notice =
      Option.join (Opium.Context.find key_notice res.Opium.Response.env)
    in
    let custom =
      Option.join (Opium.Context.find key_custom res.Opium.Response.env)
    in
    let next_flash =
      { alert; notice; custom } |> to_yojson |> Yojson.Safe.to_string
    in
    (* Put next flash message into flash store *)
    let* () =
      Sihl_facade.Session.set_value
        session
        ~k:flash_store_name
        ~v:(Some next_flash)
    in
    Lwt.return res
  in
  Rock.Middleware.create ~name:"session.flash" ~filter
;;
