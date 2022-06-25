open Command_pure
module Config = Sihl__config.Config
open Cohttp_lwt_unix

let download (uri : Uri.t) (dest : string) =
  let tar =
    try Ok (FileUtil.which "tar") with
    | _ ->
      Error
        "can not install esbuild, install it manually by putting the \
         executable into the project root or by adjusting $PATH"
  in
  match tar with
  | Error msg -> Lwt.return (Error msg)
  | Ok tar ->
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
    FileUtil.rm
      ~recurse:true
      [ Filename.concat (Config.root_path ()) "package" ];
    FileUtil.rm [ dest_tar ];
    Lwt.return (Ok ())
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

let esbuild_args =
  [| "--bundle"
   ; "assets/js/app.js"
   ; "--outdir=static/assets"
   ; "--target=es2016"
   ; "--sourcemap=inline"
   ; "--watch"
  |]
;;

let esbuild_path () =
  let path_which =
    try Some (FileUtil.which "esbuild") with
    | _ -> None
  in
  let path_local = Filename.concat (Config.root_path ()) "esbuild" in
  match path_which, CCIO.File.exists path_local with
  | _, true -> Lwt.return (Ok path_local)
  | Some path, false -> Lwt.return (Ok path)
  | None, false ->
    print_endline "esbuild not found, installing...";
    (try%lwt install_esbuild () |> Lwt_result.map (fun _ -> path_local) with
    | _ ->
      let msg =
        "can not install esbuild, install it manually by putting the \
         executable into the project root or by adjusting $PATH"
      in
      print_endline msg;
      Lwt.return (Error msg))
;;

let fn _ =
  let module M = Minicli.CLI in
  M.finalize ();
  let bin_dir = Config.absolute_path "_build/default/bin/" in
  let bin_path = Filename.concat bin_dir "bin.exe" in
  print_endline @@ Format.sprintf "start development server";
  let bin_dune = Config.absolute_path "/_opam/bin/dune" in
  let assets_dir = Filename.concat (Config.static_dir ()) "assets/" in
  let watch () =
    Unix.putenv "SIHL_ENV" "local";
    print_endline "watching for changes";
    let%lwt inotify = Lwt_inotify.create () in
    let rec loop ?pid () =
      match%lwt Lwt_unix.file_exists bin_path with
      | false ->
        print_endline "waiting for initial compile to finish";
        let%lwt () = Lwt_unix.sleep 1.0 in
        loop ?pid ()
      | true ->
        let pid =
          match pid with
          | Some pid -> pid
          | None -> Spawn.spawn ~prog:bin_path ~argv:[ "bin.exe"; "start" ] ()
        in
        let%lwt ((_, kind, _, filename) as _event) = Lwt_inotify.read inotify in
        (* print_endline (Inotify.string_of_event _event); *)
        (match kind, filename with
        | _, Some "bin.exe"
        | [ Inotify.Close_write ], Some "app.js"
        | [ Inotify.Close_write ], Some "app.css" ->
          print_endline "restart server";
          Unix.kill pid Sys.sigint;
          print_endline "wait for server to shutdown";
          Unix.waitpid [] pid |> ignore;
          loop ()
        | _ -> loop ~pid ())
    in
    Spawn.spawn ~prog:bin_dune ~argv:[ "dune"; "build"; "--root=."; "-w" ] ()
    |> ignore;
    let%lwt _ = Lwt_inotify.add_watch inotify assets_dir [ Inotify.S_All ] in
    let%lwt _ = Lwt_inotify.add_watch inotify bin_dir [ Inotify.S_Attrib ] in
    match%lwt esbuild_path () with
    | Ok esbuild ->
      let args = List.cons "esbuild" (Array.to_list esbuild_args) in
      Spawn.spawn ~prog:esbuild ~argv:args () |> ignore;
      let%lwt () = Lwt_unix.sleep 1.0 in
      loop ()
    | Error msg ->
      print_endline msg;
      let%lwt () = Lwt_unix.sleep 1.0 in
      loop ()
  in
  Lwt_main.run (watch ())
;;

let fn_asset _ =
  let run () =
    let%lwt esbuild_path = esbuild_path () in
    let _ = Unix.execv (Result.get_ok esbuild_path) esbuild_args in
    Lwt.return ()
  in
  Lwt_main.run (run ())
;;

let t : t =
  { name = "dev"
  ; description = "Bundle assets and build the Sihl project"
  ; usage = "sihl dev"
  ; fn
  ; stateful = false
  }
;;

let assets : t =
  { name = "dev.assets"
  ; description = "Bundle assets and watch for changes"
  ; usage = "sihl dev.assets"
  ; fn = fn_asset
  ; stateful = false
  }
;;

let build : t =
  { name = "dev.build"
  ; description =
      "Build the Sihl project, start the HTTP server and watch for changes"
  ; usage = "sihl dev.build"
  ; fn
  ; stateful = false
  }
;;
