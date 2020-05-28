open Base

let ( let* ) = Lwt.bind

module Message = Middleware_flash_model.Message
module Entry = Middleware_flash_model.Entry
module Store = Middleware_flash_store

let key : string Opium.Hmap.key =
  Opium.Hmap.Key.create ("/flash/id", fun _ -> sexp_of_string "/flash/id")

let m () =
  let filter handler req =
    let* () = Store.rotate req in
    handler req
  in
  Opium.Std.Rock.Middleware.create ~name:"flash" ~filter

let current req =
  let* entry = Store.find_current req in
  match entry with
  | None ->
      Logs.warn (fun m ->
          m
            "FLASH: No flash message found, have you applied the flash \
             middleware?");
      Lwt.return None
  | Some message -> Lwt.return @@ Some message

let set req message = Store.set_next req message

let set_success req txt = set req (Message.success txt)

let set_error req txt = set req (Message.error txt)

let redirect_with_error req ~path txt =
  let* () = set_error req txt in
  Http.Res.empty |> Http.Res.redirect path |> Lwt.return

let redirect_with_success req ~path txt =
  let* () = set_success req txt in
  Http.Res.empty |> Http.Res.redirect path |> Lwt.return
