module Core = Sihl_core
module Session = Sihl_session
open Lwt.Syntax
module Entry = Model.Entry

let log_src = Logs.Src.create ~doc:"message" "sihl.service.message"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let session_key = "message"

module Make (SessionService : Session.Sig.SERVICE) : Sig.SERVICE = struct
  let fetch_entry ctx session =
    let* entry = SessionService.get ctx session ~key:session_key in
    match entry with
    | None -> Lwt.return None
    | Some entry ->
      (match entry |> Entry.of_string with
      | Ok entry -> Lwt.return (Some entry)
      | Error msg ->
        Logs.warn (fun m -> m "MESSAGE: Invalid flash message in session %s" msg);
        Lwt.return None)
  ;;

  let find_current ctx session =
    let* entry = fetch_entry ctx session in
    match entry with
    | None -> Lwt.return None
    | Some entry -> Lwt.return (Entry.current entry)
  ;;

  let set_next ctx session message =
    let* entry = fetch_entry ctx session in
    match entry with
    | None ->
      (* No entry found, creating new one *)
      let entry = Entry.create message |> Entry.to_string in
      SessionService.set ctx session ~key:session_key ~value:entry
    | Some entry ->
      (* Overriding next message in existing entry *)
      let entry = Entry.set_next message entry |> Entry.to_string in
      SessionService.set ctx session ~key:session_key ~value:entry
  ;;

  let rotate ctx session =
    let* entry = fetch_entry ctx session in
    match entry with
    | None -> Lwt.return None
    | Some entry ->
      let serialized_entry = entry |> Entry.rotate |> Entry.to_string in
      let* () = SessionService.set ctx session ~key:session_key ~value:serialized_entry in
      Lwt.return @@ Model.Entry.next entry
  ;;

  let current ctx session =
    let* entry = find_current ctx session in
    match entry with
    | None -> Lwt.return None
    | Some message -> Lwt.return (Some message)
  ;;

  let set ctx session ?(error = []) ?(warning = []) ?(success = []) ?(info = []) () =
    let message =
      Model.Message.(
        empty
        |> set_error error
        |> set_warning warning
        |> set_success success
        |> set_info info)
    in
    set_next ctx session message
  ;;

  let start ctx = Lwt.return ctx
  let stop _ = Lwt.return ()

  let lifecycle =
    Core.Container.Lifecycle.create
      "message"
      ~dependencies:[ SessionService.lifecycle ]
      ~start
      ~stop
  ;;

  let register () = Core.Container.Service.create lifecycle
end
