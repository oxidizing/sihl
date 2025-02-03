let get_log_level () =
  match Sys.getenv_opt "LOG_LEVEL" with
  | Some "debug" -> Some Logs.Debug
  | Some "error" -> Some Logs.Error
  | Some "warning" -> Some Logs.Warning
  | _ -> Some Logs.Info
;;

let logs_dir () =
  match
    Core_configuration.root_path (), Core_configuration.read_string "LOGS_DIR"
  with
  | _, Some logs_dir -> logs_dir
  | Some root, None -> root ^ "/logs"
  | None, None -> "logs"
;;

let lwt_file_reporter () =
  let logs_dir = logs_dir () in
  let buf () =
    let b = Buffer.create 512 in
    ( b
    , fun () ->
        let m = Buffer.contents b in
        Buffer.reset b;
        m )
  in
  let app, app_flush = buf () in
  let err, err_flush = buf () in
  let report src level ~over k msgf =
    let k _ = k () in
    let write () =
      let name =
        match level with
        | Logs.Error -> logs_dir ^ "/error.log"
        | _ -> logs_dir ^ "/app.log"
      in
      let%lwt log =
        Lwt_io.open_file
          ~flags:[ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_APPEND ]
          ~perm:0o777
          ~mode:Lwt_io.Output
          name
      in
      let%lwt () =
        match level with
        | Logs.Error -> Lwt_io.write log (err_flush ())
        | _ -> Lwt_io.write log (app_flush ())
      in
      Lwt_io.close log
    in
    let unblock () =
      over ();
      Lwt.return_unit
    in
    Lwt.finalize write unblock |> Lwt.ignore_result;
    msgf
    @@ fun ?header:_ ?tags:_ fmt ->
    let now = Ptime_clock.now () |> Ptime.to_rfc3339 in
    match level with
    | Logs.Error ->
      let ppf = Format.formatter_of_buffer err in
      Format.kfprintf
        k
        ppf
        ("%s [%s]: @[" ^^ fmt ^^ "@]@.")
        now
        (Logs.Src.name src)
    | _ ->
      let ppf = Format.formatter_of_buffer app in
      Format.kfprintf
        k
        ppf
        ("%s [%a] [%s]: @[" ^^ fmt ^^ "@]@.")
        now
        Logs.pp_level
        level
        (Logs.Src.name src)
  in
  { Logs.report }
;;

let app_style = `Cyan
let err_style = `Red
let warn_style = `Yellow
let info_style = `Blue
let debug_style = `Green
let source_style = `Magenta

let pp_header ~pp_h ppf (l, h) =
  match l with
  | Logs.App ->
    (match h with
     | None -> ()
     | Some h -> Fmt.pf ppf "[%a] " Fmt.(styled app_style string) h)
  | Logs.Error ->
    pp_h
      ppf
      err_style
      (match h with
       | None -> "ERROR"
       | Some h -> h)
  | Logs.Warning ->
    pp_h
      ppf
      warn_style
      (match h with
       | None -> "WARNING"
       | Some h -> h)
  | Logs.Info ->
    pp_h
      ppf
      info_style
      (match h with
       | None -> "INFO"
       | Some h -> h)
  | Logs.Debug ->
    pp_h
      ppf
      debug_style
      (match h with
       | None -> "DEBUG"
       | Some h -> h)
;;

let pp_source = Fmt.(styled source_style string)

let pp_exec_header src =
  let pp_h ppf style h =
    let src = Logs.Src.name src in
    let now = Ptime_clock.now () |> Ptime.to_rfc3339 in
    Fmt.pf ppf "%s [%a] [%a]: " now Fmt.(styled style string) h pp_source src
  in
  pp_header ~pp_h
;;

let format_reporter
      ?(pp_header = pp_exec_header)
      ?(app = Format.std_formatter)
      ?(dst = Format.err_formatter)
      ()
  =
  let report src level ~over k msgf =
    let k _ =
      over ();
      k ()
    in
    msgf
    @@ fun ?header ?tags:_ fmt ->
    let ppf = if level = Logs.App then app else dst in
    Format.kfprintf
      k
      ppf
      ("%a@[" ^^ fmt ^^ "@]@.")
      (pp_header src)
      (level, header)
  in
  { Logs.report }
;;

let cli_reporter ?(pp_header = pp_exec_header) ?app ?dst () =
  Fmt_tty.setup_std_outputs ();
  format_reporter ~pp_header ?app ?dst ()
;;

let combine r1 r2 =
  let report src level ~over k msgf =
    let v = r1.Logs.report src level ~over:(fun () -> ()) k msgf in
    r2.Logs.report src level ~over (fun () -> v) msgf
  in
  { Logs.report }
;;

let default_reporter =
  Logs.set_level (get_log_level ());
  let r1 = lwt_file_reporter () in
  let r2 = cli_reporter () in
  combine r1 r2
;;
