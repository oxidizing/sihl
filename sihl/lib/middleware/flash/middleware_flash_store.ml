open Base

let ( let* ) = Lwt_result.bind

module Entry = Middleware_flash_model.Entry

let fetch_entry req =
  let* entry = Http.Session.get "flash" req in
  match entry with
  | None -> Lwt.return @@ Ok None
  | Some entry -> (
      match entry |> Entry.of_string with
      | Ok entry -> Lwt.return @@ Ok (Some entry)
      | Error msg ->
          Logs.warn (fun m ->
              m "FLASH: Invalid flash message in session %s" msg);
          Lwt.return @@ Ok None )

let find_current req =
  let* entry = fetch_entry req in
  match entry with
  | None -> Lwt.return @@ Ok None
  | Some entry -> Lwt.return @@ Ok (Entry.current entry)

let set_next req message =
  let* entry = fetch_entry req in
  match entry with
  | None ->
      (* No entry found, creating new one *)
      let entry = Entry.create message |> Entry.to_string in
      Http.Session.set ~key:"flash" ~value:entry req
  | Some entry ->
      (* Overriding next message in existing entry *)
      let entry = Entry.set_next message entry |> Entry.to_string in
      Http.Session.set ~key:"flash" ~value:entry req

let rotate req =
  let* entry = fetch_entry req in
  match entry with
  | None -> Lwt.return @@ Ok ()
  | Some entry ->
      let entry = entry |> Entry.rotate |> Entry.to_string in
      Http.Session.set ~key:"flash" ~value:entry req
