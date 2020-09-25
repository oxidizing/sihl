open Opium_kernel__Misc
open Sexplib.Std
module Server = Cohttp_lwt_unix.Server
open Opium_kernel.Rock

type t = { prefix : string; local_path : string } [@@deriving fields, sexp]

let legal_path { prefix; local_path } requested =
  let p = String.chop_prefix requested ~prefix in
  let requested_path = Filename.concat local_path p in
  if String.is_prefix requested_path ~prefix:local_path then Some requested_path
  else None

let public_serve t ~requested ~request_if_none_match ?etag_of_fname ?headers ()
    =
  match legal_path t requested with
  | None -> return `Not_found
  | Some legal_path ->
      let etag_quoted =
        match etag_of_fname with
        | Some f -> Some (Printf.sprintf "%S" (f legal_path))
        | None -> None
      in
      let mime_type = Magic_mime.lookup legal_path in
      let headers =
        Cohttp.Header.add_opt_unless_exists headers "content-type" mime_type
      in
      let headers =
        match etag_quoted with
        | Some etag_quoted ->
            Cohttp.Header.add_unless_exists headers "etag" etag_quoted
        | None -> headers
      in
      let request_matches_etag =
        match (request_if_none_match, etag_quoted) with
        | Some request_etags, Some etag_quoted ->
            request_etags |> Stringext.split ~on:','
            |> List.exists ~f:(fun request_etag ->
                   String.trim request_etag = etag_quoted)
        | _ -> false
      in
      if request_matches_etag then
        `Ok (Response.create ~code:`Not_modified ~headers ()) |> Lwt.return
      else
        Server.respond_file ~headers ~fname:legal_path () >>| fun resp ->
        if resp |> fst |> Cohttp.Response.status = `Not_found then `Not_found
        else `Ok (Response.of_response_body resp)

let m ~local_path_f ~uri_prefix_f ?headers ?etag_of_fname () =
  let filter handler ctx =
    let local_path = local_path_f () in
    let uri_prefix = uri_prefix_f () in

    if Http.Req.is_get ctx then
      let local_map = { prefix = uri_prefix; local_path } in
      let local_path = ctx |> Http.Req.get_uri |> Uri.path in
      if local_path |> String.is_prefix ~prefix:uri_prefix then
        let request_if_none_match = Http.Req.get_header ctx "If-None-Match" in
        public_serve local_map ~requested:local_path ~request_if_none_match
          ?etag_of_fname ?headers ()
        >>= function
        | `Not_found -> handler ctx
        | `Ok x -> return Http.Res.(html |> set_opium_res x)
      else handler ctx
    else handler ctx
  in
  Middleware_core.create ~name:"static" filter
