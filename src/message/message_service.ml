open Base

let ( let* ) = Lwt_result.bind

module Entry = Message_core.Entry

let session_key = "message"

let fetch_entry ctx =
  let* entry = Session.get_value ~key:session_key ctx in
  match entry with
  | None -> Lwt.return @@ Ok None
  | Some entry -> (
      match entry |> Entry.of_string with
      | Ok entry -> Lwt.return @@ Ok (Some entry)
      | Error msg ->
          Logs.warn (fun m ->
              m "MESSAGE: Invalid flash message in session %s" msg);
          Lwt.return @@ Ok None )

let find_current ctx =
  let* entry = fetch_entry ctx in
  match entry with
  | None -> Lwt.return @@ Ok None
  | Some entry -> Lwt.return @@ Ok (Entry.current entry)

let set_next ctx message =
  let* entry = fetch_entry ctx in
  match entry with
  | None ->
      (* No entry found, creating new one *)
      let entry = Entry.create message |> Entry.to_string in
      Session.set_value ctx ~key:session_key ~value:entry
  | Some entry ->
      (* Overriding next message in existing entry *)
      let entry = Entry.set_next message entry |> Entry.to_string in
      Session.set_value ctx ~key:session_key ~value:entry

let rotate ctx =
  let* entry = fetch_entry ctx in
  match entry with
  | None -> Lwt.return @@ Ok ()
  | Some entry ->
      let entry = entry |> Entry.rotate |> Entry.to_string in
      Session.set_value ctx ~key:session_key ~value:entry

let current ctx =
  let* entry = find_current ctx in
  match entry with
  | None -> Lwt.return @@ Ok None
  | Some message -> Lwt.return @@ Ok (Some message)

let set ctx ?(error = []) ?(warning = []) ?(success = []) ?(info = []) () =
  let message =
    Message_core.Message.(
      empty |> set_error error |> set_warning warning |> set_success success
      |> set_info info)
  in
  set_next ctx message

let get = current
