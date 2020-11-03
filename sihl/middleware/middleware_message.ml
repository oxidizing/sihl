module Http = Sihl_http
module Message = Sihl_message
open Lwt.Syntax

let log_src = Logs.Src.create ~doc:"Message Middleware" "sihl.middleware.message"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let key : Message.t Opium_kernel.Hmap.key =
  Opium_kernel.Hmap.Key.create ("message", Message.sexp_of_t)
;;

let find_opt req = Opium_kernel.Hmap.find key (Opium_kernel.Request.env req)

let set message req =
  let env = Opium_kernel.Request.env req in
  let env = Opium_kernel.Hmap.add key message env in
  { req with env }
;;

module Make (MessageService : Message.Sig.SERVICE) = struct
  let m () =
    let filter handler req =
      let ctx = Http.Request.to_ctx req in
      let session =
        match Middleware_session.find_opt req with
        | Some session -> session
        | None ->
          Logs.info (fun m -> m "Did you forget to apply the session middleware?");
          Logs.err (fun m -> m "No session found");
          failwith "No session found"
      in
      let* result = MessageService.rotate ctx session in
      match result with
      | Some message ->
        let req = set message req in
        handler req
      | None -> handler req
    in
    Opium_kernel.Rock.Middleware.create ~name:"message" ~filter
  ;;
end
