open Base

let ( let* ) = Lwt_result.bind

module Message = Web_middleware_flash_model.Message
module Entry = Web_middleware_flash_model.Entry
module Store = Web_middleware_flash_store

let key : string Opium.Hmap.key =
  Opium.Hmap.Key.create ("flash", fun _ -> sexp_of_string "flash")

let m () =
  let filter handler req =
    let ctx = Web_req.ctx_of req in
    let ( let* ) = Lwt.bind in
    let* result = Store.rotate ctx in
    let () = result |> Result.ok_or_failwith in
    handler req
  in
  Web_middleware_core.create ~name:"flash" filter

let current req =
  let* entry = Store.find_current req in
  match entry with
  | None -> Lwt.return @@ Ok None
  | Some message -> Lwt.return @@ Ok (Some message)

let set req message = Store.set_next req message

let set_success req txt = set req (Message.success txt)

let set_error req txt = set req (Message.error txt)

let redirect_with_error req ~path txt =
  let* () = set_error req txt in
  Web_res.set_redirect path |> Result.return |> Lwt.return

let redirect_with_success req ~path txt =
  let* () = set_success req txt in
  Web_res.set_redirect path |> Result.return |> Lwt.return
