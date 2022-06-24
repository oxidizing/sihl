open Command_pure
module Config = Sihl__config.Config
open Cohttp_lwt_unix

let download (uri : Uri.t) (dest : string) =
  let tar =
    try FileUtil.which "tar" with
    | _ ->
      failwith
        "can not install esbuild, install it manually by putting the \
         executable into the project root or by adjusting $PATH"
  in
  let%lwt _, body = Client.get uri in
  (* TODO: check response for status codes, follow redirects if applicable *)
  let stream = Cohttp_lwt.Body.to_stream body in
  let dest_tar = Format.sprintf "%s.tar.gz" dest in
  print_endline @@ Format.sprintf "download %s" dest_tar;
  let%lwt () =
    Lwt_io.with_file ~mode:Lwt_io.output dest_tar (fun chan_tmp ->
        Lwt_stream.iter_s (Lwt_io.write chan_tmp) stream)
  in
  print_endline @@ Format.sprintf "extract %s" dest_tar;
  let pid = Spawn.spawn ~prog:tar ~argv:[ "-z"; "-x"; "-f"; dest_tar ] () in
  let _ = Unix.waitpid [] pid in
  let src = Filename.concat (Config.root_path ()) "package/bin/esbuild" in
  FileUtil.mv src dest;
  print_endline "clean up";
  FileUtil.rm ~recurse:true [ Filename.concat (Config.root_path ()) "package" ];
  FileUtil.rm [ dest_tar ];
  Lwt.return ()
;;

let install_esbuild () =
  let dest = Filename.concat (Config.root_path ()) "esbuild" in
  let ic = Unix.open_process_in "uname" in
  let uname = input_line ic in
  let () = close_in ic in
  match Sys.int_size, uname with
  | 63, "Darwin" ->
    download
      (Uri.of_string
         "https://registry.npmjs.org/esbuild-darwin-64/-/esbuild-darwin-64-0.14.45.tgz")
      dest
  | 31, "Linux" ->
    download
      (Uri.of_string
         "https://registry.npmjs.org/esbuild-linux-32/-/esbuild-linux-32-0.14.45.tgz")
      dest
  | 63, "Linux" ->
    download
      (Uri.of_string
         "https://registry.npmjs.org/esbuild-linux-64/-/esbuild-linux-64-0.14.45.tgz")
      dest
  | _ ->
    failwith
      "can not install esbuild, install it manually by putting the executable \
       into the project root or by adjusting $PATH"
;;

let fn _ =
  let path_which =
    try Some (FileUtil.which "esbuild") with
    | _ -> None
  in
  let path_local = Filename.concat (Config.root_path ()) "esbuild" in
  Lwt_main.run
    (let%lwt path =
       match path_which, CCIO.File.exists path_local with
       | _, true -> Lwt.return path_local
       | Some path, false -> Lwt.return path
       | None, false ->
         print_endline "esbuild not found, installing...";
         let%lwt () =
           try%lwt install_esbuild () with
           | e ->
             print_endline
               "can not install esbuild, install it manually by putting the \
                executable into the project root or by adjusting $PATH";
             raise e
         in
         Lwt.return path_local
     in
     let _ =
       Unix.execv
         path
         [| "--bundle"; "static/project.js"; "--watch"; "--outdir=dist" |]
     in
     Lwt.return ())
;;

let t : t =
  { name = "static"
  ; description = "Builds, minifies and bundles the static files"
  ; usage = "sihl static"
  ; fn
  ; stateful = false
  }
;;
