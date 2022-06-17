module Config = Sihl__config.Config

let () =
  Omigrate.Driver.register "postgres" (module Driver_postgresql.T);
  Omigrate.Driver.register "postgresql" (module Driver_postgresql.T)
;;

let sql = Migration_sql.sql

let generate (path : string) : unit Lwt.t =
  let up, down = Migration_sql.sql () in
  let tm = Unix.gmtime (Unix.time ()) in
  (* From omigrate, wait for API to support this *)
  let date =
    Printf.sprintf
      "%d%02d%02d%02d%02d%02d"
      (1900 + tm.Unix.tm_year)
      (1 + tm.Unix.tm_mon)
      tm.Unix.tm_mday
      tm.Unix.tm_hour
      tm.Unix.tm_min
      tm.Unix.tm_sec
  in
  let migration_name = Printf.sprintf "%s_%s" date "initial_create_tables" in
  let%lwt () =
    Lwt_io.with_file
      ~mode:Output
      (Filename.concat path (Printf.sprintf "%s.up.sql" migration_name))
      (fun io -> Lwt_io.write io up)
  in
  Lwt_io.with_file
    ~mode:Output
    (Filename.concat path (Printf.sprintf "%s.down.sql" migration_name))
    (fun io -> Lwt_io.write io down)
;;

let up ?(path = Config.absolute_path "migrations") () : unit Lwt.t =
  let database = Config.database_url () |> Uri.to_string in
  let%lwt () = generate path in
  let%lwt () =
    Omigrate.up ~source:path ~database
    |> Lwt_result.map_err Omigrate.Error.to_string
    |> Lwt.map CCResult.get_or_failwith
  in
  Lwt.return ()
;;
