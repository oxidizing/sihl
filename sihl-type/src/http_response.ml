include Opium.Response

exception Isnt_a_file

let log_src = Logs.Src.create "sihl.http.response"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let read fname =
  let open Lwt.Syntax in
  let bufsize = 4096 in
  Lwt.catch
    (fun () ->
      let* s = Lwt_unix.stat fname in
      let* () =
        if Unix.(s.st_kind <> S_REG) then Lwt.fail Isnt_a_file else Lwt.return_unit
      in
      let* ic =
        Lwt_io.open_file
          ~buffer:(Lwt_bytes.create bufsize)
          ~flags:[ O_RDONLY ]
          ~mode:Lwt_io.input
          fname
      in
      let+ size = Lwt_io.length ic in
      let stream =
        Lwt_stream.from (fun () ->
            Lwt.catch
              (fun () ->
                let+ b = Lwt_io.read ~count:bufsize ic in
                match b with
                | "" -> None
                | buf -> Some buf)
              (fun exn ->
                Logs.warn (fun m ->
                    m "Error while reading file %s. %s" fname (Printexc.to_string exn));
                Lwt.return_none))
      in
      Lwt.on_success (Lwt_stream.closed stream) (fun () ->
          Lwt.async (fun () -> Lwt_io.close ic));
      Ok (Opium.Body.of_stream ~length:size stream))
    (fun e ->
      match e with
      | Isnt_a_file | Unix.Unix_error (Unix.ENOENT, _, _) -> Lwt.return (Error `Not_found)
      | exn ->
        Logs.err (fun m ->
            m "Unknown error while serving file %s. %s" fname (Printexc.to_string exn));
        Lwt.fail exn)
;;

let of_file
    fname
    ?(version = { Httpaf.Version.major = 1; minor = 1 })
    ?(reason = "")
    ?(headers = Httpaf.Headers.empty)
    ?(env = Opium.Context.empty)
    ()
  =
  let open Lwt.Syntax in
  let* body = read fname in
  match body with
  | Error status ->
    let res =
      Rock.Response.make
        ~version
        ~headers
        ~reason
        ~env
        ~status:(status :> Httpaf.Status.t)
        ()
    in
    Lwt.return res
  | Ok body ->
    let mime_type = Magic_mime.lookup fname in
    let headers = Httpaf.Headers.add_unless_exists headers "Content-Type" mime_type in
    let res = Rock.Response.make ~version ~headers ~reason ~env ~status:`OK ~body () in
    Lwt.return res
;;
