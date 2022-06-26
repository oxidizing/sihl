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

(* TODO Consider using a simpler approach with
   https://watchexec.github.io/downloads/ *)
(* have app/server, app/app, app/.... *)
(* watchexec -e re,ml,rei,mli -r -- esy dune exec ./main.exe *)
(* 1. ./esbuild --bundle assets/js/app.js --outdir=static/assets --target=es2016
   --sourcemap=inline --watch *)
(* 2. watchexec -r -e .ml,.re,.js,.css,.png,.jpg,.ico,.json -i */assets/**/* --
   dune exec bin/bin.exe start *)
let fn _ =
  let module M = Minicli.CLI in
  M.finalize ();
  print_endline @@ Format.sprintf "start development server";
  let bin_dune = Config.bin_dune () in
  let watch () =
    Unix.putenv "SIHL_ENV" "local";
    print_endline "watching for changes";
    Spawn.spawn
      ~prog:bin_dune
      ~argv:[ "dune"; "build"; "-w"; "@run"; "--force"; "--no-buffer" ]
      ()
    |> ignore;
    let rec loop () =
      let%lwt () = Lwt_unix.sleep 0.2 in
      loop ()
    in
    match%lwt esbuild_path () with
    | Ok esbuild ->
      let args = List.cons "esbuild" (Array.to_list esbuild_args) in
      Spawn.spawn ~prog:esbuild ~argv:args () |> ignore;
      loop ()
    | Error msg ->
      print_endline msg;
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

let fn_build _ =
  let run () =
    let bin_dune = Config.bin_dune () in
    let _ = Unix.execv bin_dune [| "dune"; "build"; "-w"; "@run" |] in
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
  ; fn = fn_build
  ; stateful = false
  }
;;
