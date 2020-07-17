open Base

let ( let* ) = Lwt_result.bind

module Entry = Message_core.Entry

let session_key = "message"

module Make (SessionService : Session.Sig.SERVICE) = struct
  let fetch_entry ctx =
    let* entry = SessionService.get_value ~key:session_key ctx in
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
        SessionService.set_value ctx ~key:session_key ~value:entry
    | Some entry ->
        (* Overriding next message in existing entry *)
        let entry = Entry.set_next message entry |> Entry.to_string in
        SessionService.set_value ctx ~key:session_key ~value:entry

  let rotate ctx =
    let* entry = fetch_entry ctx in
    match entry with
    | None -> Lwt.return @@ Ok None
    | Some entry ->
        let seralized_entry = entry |> Entry.rotate |> Entry.to_string in
        let* () =
          SessionService.set_value ctx ~key:session_key ~value:seralized_entry
        in
        Lwt_result.return @@ Message_core.Entry.next entry

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
end
