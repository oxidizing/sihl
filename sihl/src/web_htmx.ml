let log_src = Logs.Src.create "sihl.middleware.htmx"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let is_htmx req = Opium.Request.header "HX-Request" req |> Option.is_some
let current_url req = Opium.Request.header "HX-Current-URL" req
let prompt req = Opium.Request.header "HX-Prompt" req

let set_prompt prompt req =
  Opium.Request.add_header_or_replace ("HX-Prompt", prompt) req
;;

let target req = Opium.Request.header "HX-Target" req

let set_target target req =
  Opium.Request.add_header_or_replace ("HX-Target", target) req
;;

let trigger_name req = Opium.Request.header "HX-Trigger-Name" req

let set_trigger_name trigger_name req =
  Opium.Request.add_header_or_replace ("HX-Trigger-Name", trigger_name) req
;;

let trigger_req req = Opium.Request.header "HX-Trigger" req

let set_trigger_req trigger req =
  Opium.Request.add_header_or_replace ("HX-Trigger", trigger) req
;;

let set_push push resp =
  Opium.Response.add_header_or_replace ("HX-Push", push) resp
;;

let set_redirect redirect resp =
  Opium.Response.add_header_or_replace ("HX-Redirect", redirect) resp
;;

let set_refresh refresh resp =
  Opium.Response.add_header_or_replace ("HX-Refresh", refresh) resp
;;

let set_trigger trigger resp =
  Opium.Response.add_header_or_replace ("HX-Trigger", trigger) resp
;;

let set_trigger_after_settle trigger_after_settle resp =
  Opium.Response.add_header_or_replace
    ("HX-Trigger-After-Settle", trigger_after_settle)
    resp
;;

let set_trigger_after_swap trigger_after_swap resp =
  Opium.Response.add_header_or_replace
    ("HX-Trigger-After-Swap", trigger_after_swap)
    resp
;;
