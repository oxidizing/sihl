module P = Command_pure
module Config = Sihl__config.Config

let fn _ =
  let module M = Minicli.CLI in
  M.finalize ();
  let bin_path = Config.absolute_path "_build/default/bin/bin.exe" in
  print_endline @@ Format.sprintf "start development server";
  let bin_dune = Config.absolute_path "/_opam/bin/dune" in
  let _ =
    Spawn.spawn ~prog:bin_dune ~argv:[ "dune"; "build"; "--root=."; "-w" ] ()
  in
  let rec loop () =
    match%lwt Lwt_unix.file_exists bin_path with
    | false -> loop ()
    | true ->
      let%lwt inotify = Lwt_inotify.create () in
      let%lwt () = Lwt_unix.sleep 1.0 in
      let pid = Spawn.spawn ~prog:bin_path ~argv:[] () in
      Unix.putenv "SIHL_ENV" "local";
      print_endline "watching for changes";
      let%lwt _ = Lwt_inotify.add_watch inotify bin_path [ Inotify.S_Attrib ] in
      let%lwt event = Lwt_inotify.read inotify in
      print_endline @@ Format.sprintf "restart server";
      Unix.kill pid 9;
      let%lwt () = Lwt_io.printl (Inotify.string_of_event event) in
      loop ()
  in
  Lwt_main.run (loop ())
;;

let t : P.t =
  { name = "dev"
  ; description = "Start a development web server"
  ; usage = "sihl dev"
  ; fn
  }
;;
