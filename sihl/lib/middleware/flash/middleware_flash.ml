open Base

let ( let* ) = Lwt_result.bind

module Message = Middleware_flash_model.Message
module Entry = Middleware_flash_model.Entry
module Store = Middleware_flash_store

let key : string Opium.Hmap.key =
  Opium.Hmap.Key.create ("flash", fun _ -> sexp_of_string "flash")

let m () =
  let filter handler req =
    let ctx = Http.ctx req in
    let ( let* ) = Lwt.bind in
    let* result = Store.rotate ctx in
    let () =
      result |> Result.map_error ~f:Core.Err.raise_server |> Result.ok_exn
    in
    handler req
  in
  Opium.Std.Rock.Middleware.create ~name:"flash" ~filter

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
  Http.Res.empty |> Http.Res.redirect path |> Result.return |> Lwt.return

let redirect_with_success req ~path txt =
  let* () = set_success req txt in
  Http.Res.empty |> Http.Res.redirect path |> Result.return |> Lwt.return
