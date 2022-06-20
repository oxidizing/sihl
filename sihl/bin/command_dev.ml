let fn _ =
  let module M = Minicli.CLI in
  M.finalize ();
  let bin_dir = Sihl.Config.absolute_path "_build/default/bin/" in
  let bin_path = Filename.concat bin_dir "bin.exe" in
  print_endline @@ Format.sprintf "start development server";
  let bin_dune = Sihl.Config.absolute_path "/_opam/bin/dune" in
  let _ =
    Spawn.spawn ~prog:bin_dune ~argv:[ "dune"; "build"; "--root=."; "-w" ] ()
  in
  let watch () =
    let%lwt inotify = Lwt_inotify.create () in
    let%lwt _ = Lwt_inotify.add_watch inotify bin_dir [ Inotify.S_Attrib ] in
    let rec loop () =
      match%lwt Lwt_unix.file_exists bin_path with
      | false ->
        print_endline "waiting for initial compile to finish";
        let%lwt () = Lwt_unix.sleep 1.0 in
        loop ()
      | true ->
        let pid = Spawn.spawn ~prog:bin_path ~argv:[] () in
        Unix.putenv "SIHL_ENV" "local";
        print_endline "watching for changes";
        let%lwt ((_, _, _, filename) as event) = Lwt_inotify.read inotify in
        let%lwt () = Lwt_io.printl (Inotify.string_of_event event) in
        (match filename with
        | Some "bin.exe" ->
          print_endline @@ Format.sprintf "restart server";
          Unix.kill pid 9;
          let%lwt () = Lwt_unix.sleep 0.1 in
          loop ()
        | _ -> loop ())
    in
    loop ()
  in
  Lwt_main.run (watch ())
;;

let t : Sihl.Command.t =
  { name = "dev"
  ; description = "Start a development web server"
  ; usage = "sihl dev"
  ; fn
  }
;;
