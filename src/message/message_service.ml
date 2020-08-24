open Base
open Lwt.Syntax
module Entry = Message_core.Entry

let session_key = "message"

module Make (Log : Log.Sig.SERVICE) (SessionService : Session.Sig.SERVICE) =
struct
  let fetch_entry ctx =
    let* entry = SessionService.get ~key:session_key ctx in
    match entry with
    | None -> Lwt.return None
    | Some entry -> (
        match entry |> Entry.of_string with
        | Ok entry -> Lwt.return (Some entry)
        | Error msg ->
            Log.warn (fun m ->
                m "MESSAGE: Invalid flash message in session %s" msg);
            Lwt.return None )

  let find_current ctx =
    let* entry = fetch_entry ctx in
    match entry with
    | None -> Lwt.return None
    | Some entry -> Lwt.return (Entry.current entry)

  let set_next ctx message =
    let* entry = fetch_entry ctx in
    match entry with
    | None ->
        (* No entry found, creating new one *)
        let entry = Entry.create message |> Entry.to_string in
        SessionService.set ctx ~key:session_key ~value:entry
    | Some entry ->
        (* Overriding next message in existing entry *)
        let entry = Entry.set_next message entry |> Entry.to_string in
        SessionService.set ctx ~key:session_key ~value:entry

  let rotate ctx =
    let* entry = fetch_entry ctx in
    match entry with
    | None -> Lwt.return None
    | Some entry ->
        let serialized_entry = entry |> Entry.rotate |> Entry.to_string in
        let* () =
          SessionService.set ctx ~key:session_key ~value:serialized_entry
        in
        Lwt.return @@ Message_core.Entry.next entry

  let current ctx =
    let* entry = find_current ctx in
    match entry with
    | None -> Lwt.return None
    | Some message -> Lwt.return (Some message)

  let set ctx ?(error = []) ?(warning = []) ?(success = []) ?(info = []) () =
    let message =
      Message_core.Message.(
        empty |> set_error error |> set_warning warning |> set_success success
        |> set_info info)
    in
    set_next ctx message
end
