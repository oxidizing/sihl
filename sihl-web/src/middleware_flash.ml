open Lwt.Syntax

let log_src = Logs.Src.create "sihl.middleware.flash"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let key : string option Opium_kernel.Hmap.key =
  Opium_kernel.Hmap.Key.create ("flash", Sexplib.Std.(sexp_of_option sexp_of_string))
;;

let find req =
  (* Raising an exception is ok since we assume that before find can be called the
     middleware has been passed *)
  Opium_kernel.Hmap.find_exn key (Opium_kernel.Request.env req)
;;

let set flash res =
  let env = Opium_kernel.Response.env res in
  let env = Opium_kernel.Hmap.add key flash env in
  { res with env }
;;

module Make (SessionService : Sihl_contract.Session.Sig) = struct
  let m ?(flash_store_name = "flash.store") () =
    let filter handler req =
      let session =
        match Middleware_session.find_opt req with
        | Some session -> session
        | None ->
          Logs.err (fun m -> m "No session found in request");
          Logs.info (fun m ->
              m
                "The flash store requires sessions. Did you forget to apply the session \
                 middleware?");
          raise @@ Sihl_contract.Session.Exception "No session found"
      in
      let* current_flash = SessionService.find_value session flash_store_name in
      let env = Opium_kernel.Request.env req in
      let env = Opium_kernel.Hmap.add key current_flash env in
      (* Put current flash message into request context *)
      let req = { req with env } in
      (* User might call set() in handler *)
      let* res = handler req in
      let next_flash =
        Option.join (Opium_kernel.Hmap.find key (Opium_kernel.Response.env res))
      in
      (* Put next flash message into flash store *)
      let* () = SessionService.set_value session ~k:flash_store_name ~v:next_flash in
      Lwt.return res
    in
    Opium_kernel.Rock.Middleware.create ~name:"flash" ~filter
  ;;
end
