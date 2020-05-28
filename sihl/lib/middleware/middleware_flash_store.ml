open Base

let ( let* ) = Lwt.bind

module Entry = Middleware_flash_model.Entry

let fetch_entry req =
  let* entry = Http.Session.get "flash" req in
  match entry with
  | None -> Lwt.return None
  | Some entry -> (
      match entry |> Entry.of_string with
      | Ok entry -> Lwt.return @@ Some entry
      | Error msg ->
          Logs.warn (fun m ->
              m "FLASH: Invalid flash message in session %s" msg);
          Lwt.return None )

let find_current req =
  let* entry = fetch_entry req in
  match entry with
  | None -> Lwt.return None
  | Some entry -> Lwt.return @@ Entry.current entry

let set_next req message =
  let* entry = fetch_entry req in
  match entry with
  | None -> Lwt.return ()
  | Some entry ->
      let entry = Entry.set_next entry message |> Entry.to_string in
      Http.Session.set ~key:"flash" ~value:entry req

let rotate req =
  let* entry = fetch_entry req in
  match entry with
  | None -> Lwt.return ()
  | Some entry ->
      let entry = entry |> Entry.rotate |> Entry.to_string in
      Http.Session.set ~key:"flash" ~value:entry req
