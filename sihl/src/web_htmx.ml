open Sexplib.Std

let log_src = Logs.Src.create "sihl.middleware.htmx"

module Logs = (val Logs.src_log log_src : Logs.LOG)

exception Exception

type req =
  { current_url : string
  ; prompt : string option
  ; target : string option
  ; trigger_name : string option
  ; trigger : string option
  }
[@@deriving sexp]

let key_req : req Opium.Context.key =
  Opium.Context.Key.create ("htmx.request", sexp_of_req)
;;

let find_htmx_req req =
  let env = req.Opium.Request.env in
  let req = Opium.Context.find key_req env in
  match req with
  | None ->
    Logs.err (fun m ->
        m
          "Request doesn't seem to be a valid HTMX request or the HTMX \
           middleware was not installed correctly.");
    raise Exception
  | Some req -> req
;;

let set_htmx_req v req =
  let env = req.Opium.Request.env in
  let env = Opium.Context.add key_req v env in
  Opium.Request.{ req with env }
;;

let is_htmx req = Opium.Request.header "HX-Request" req |> Option.is_some
let current_url req = (find_htmx_req req).current_url

let create_with_current_url current_url req =
  let htmx_req =
    { current_url
    ; prompt = None
    ; target = None
    ; trigger_name = None
    ; trigger = None
    }
  in
  set_htmx_req htmx_req req
;;

let prompt req = (find_htmx_req req).prompt

let set_prompt prompt req =
  let htmx_req = find_htmx_req req in
  set_htmx_req { htmx_req with prompt } req
;;

let target req = (find_htmx_req req).target

let set_target target req =
  let htmx_req = find_htmx_req req in
  set_htmx_req { htmx_req with target } req
;;

let trigger_name req = (find_htmx_req req).trigger_name

let set_trigger_name trigger_name req =
  let htmx_req = find_htmx_req req in
  set_htmx_req { htmx_req with trigger_name } req
;;

let trigger_req req = (find_htmx_req req).trigger

let set_trigger_req trigger req =
  let htmx_req = find_htmx_req req in
  set_htmx_req { htmx_req with trigger } req
;;

type res =
  { push : string option
  ; redirect : string option
  ; refresh : string option
  ; trigger : string option
  ; trigger_after_settle : string option
  ; trigger_after_swap : string option
  }
[@@deriving sexp]

let empty_htmx_res =
  { push = None
  ; redirect = None
  ; refresh = None
  ; trigger = None
  ; trigger_after_settle = None
  ; trigger_after_swap = None
  }
;;

let key_res : res Opium.Context.key =
  Opium.Context.Key.create ("htmx.response", sexp_of_res)
;;

let find_htmx_res res =
  let env = res.Opium.Response.env in
  Opium.Context.find key_res env
;;

let set_htmx_res v res =
  let env = res.Opium.Response.env in
  let env = Opium.Context.add key_res v env in
  Opium.Response.{ res with env }
;;

let set_push push res =
  let value = find_htmx_res res in
  match value with
  | None -> set_htmx_res { empty_htmx_res with push } res
  | Some value -> set_htmx_res { value with push } res
;;

let set_redirect redirect res =
  let value = find_htmx_res res in
  match value with
  | None -> set_htmx_res { empty_htmx_res with redirect } res
  | Some value -> set_htmx_res { value with redirect } res
;;

let set_refresh refresh res =
  let value = find_htmx_res res in
  match value with
  | None -> set_htmx_res { empty_htmx_res with refresh } res
  | Some value -> set_htmx_res { value with refresh } res
;;

let set_trigger trigger res =
  let value = find_htmx_res res in
  match value with
  | None -> set_htmx_res { empty_htmx_res with trigger } res
  | Some value -> set_htmx_res { value with trigger } res
;;

let set_trigger_after_settle trigger_after_settle res =
  let value = find_htmx_res res in
  match value with
  | None -> set_htmx_res { empty_htmx_res with trigger_after_settle } res
  | Some value -> set_htmx_res { value with trigger_after_settle } res
;;

let set_trigger_after_swap trigger_after_swap res =
  let value = find_htmx_res res in
  match value with
  | None -> set_htmx_res { empty_htmx_res with trigger_after_swap } res
  | Some value -> set_htmx_res { value with trigger_after_swap } res
;;

let add_htmx_resp_header header value resp =
  match value with
  | None -> resp
  | Some value -> Opium.Response.add_header_unless_exists (header, value) resp
;;

let middleware =
  let open Lwt.Syntax in
  let filter handler req =
    match Opium.Request.header "HX-Request" req with
    | None -> handler req
    | Some _ ->
      let req =
        match Opium.Request.header "HX-Current-URL" req with
        | Some current_url -> create_with_current_url current_url req
        | None -> req
      in
      let req = set_prompt (Opium.Request.header "HX-Prompt" req) req in
      let req = set_target (Opium.Request.header "HX-Target" req) req in
      let req =
        set_trigger_name (Opium.Request.header "HX-Trigger-Name" req) req
      in
      let req = set_trigger_req (Opium.Request.header "HX-Trigger" req) req in
      let req = set_trigger_req (Opium.Request.header "HX-Trigger" req) req in
      let* resp = handler req in
      let htmx_resp = find_htmx_res resp in
      (match htmx_resp with
      | None -> Lwt.return resp
      | Some htmx_resp ->
        let resp = add_htmx_resp_header "HX-Push" htmx_resp.push resp in
        let resp = add_htmx_resp_header "HX-Redirect" htmx_resp.redirect resp in
        let resp = add_htmx_resp_header "HX-Refresh" htmx_resp.refresh resp in
        let resp = add_htmx_resp_header "HX-Trigger" htmx_resp.trigger resp in
        let resp =
          add_htmx_resp_header
            "HX-Trigger-After-Settle"
            htmx_resp.trigger_after_settle
            resp
        in
        let resp =
          add_htmx_resp_header
            "HX-Trigger-After-Swap"
            htmx_resp.trigger_after_swap
            resp
        in
        Lwt.return resp)
  in
  Rock.Middleware.create ~name:"htmx" ~filter
;;
