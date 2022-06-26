(* TODO add mariadb and sqlite using caqti *)
module T = struct
  let migrations_table = "schema_migrations"
  let quote_statement s = "\"" ^ s ^ "\""

  let with_conn ~host ~port ~user ~password ?database f =
    let open Lwt.Syntax in
    let* () =
      Logs_lwt.debug (fun m ->
          m
            "Opening a conection on postgres://%s:%s@%s:%d/%a"
            user
            password
            host
            port
            (Format.pp_print_option Format.pp_print_string)
            database)
    in
    Pgx_lwt_unix.with_conn ~host ~port ~user ~password ?database f
  ;;

  let database_exists ~conn database =
    let open Lwt.Syntax in
    let* () = Logs_lwt.debug (fun m -> m "Querying existing databases") in
    let+ result =
      Pgx_lwt_unix.execute
        ~params:[ Pgx.Value.(of_string database) ]
        conn
        "SELECT EXISTS(SELECT datname FROM pg_catalog.pg_database WHERE \
         datname = $1);"
    in
    result |> List.hd |> List.hd |> Pgx.Value.to_bool_exn
  ;;

  let version_exists ~conn version =
    let open Lwt.Syntax in
    let* () = Logs_lwt.debug (fun m -> m "Querying existing versions") in
    let+ result =
      Pgx_lwt_unix.execute
        ~params:[ Pgx.Value.(of_int64 version) ]
        conn
        ("SELECT EXISTS(SELECT version FROM "
        ^ quote_statement migrations_table
        ^ " WHERE version = $1);")
    in
    result |> List.hd |> List.hd |> Pgx.Value.to_bool_exn
  ;;

  let ensure_version_table_exists ~conn =
    let open Lwt.Syntax in
    let* () = Logs_lwt.info (fun m -> m "Creating the migrations table") in
    Pgx_lwt_unix.execute_unit
      conn
      ("CREATE TABLE IF NOT EXISTS "
      ^ quote_statement migrations_table
      ^ " (version bigint not null primary key);")
  ;;

  let up ~host ~port ~user ~password ~database migration =
    let open Lwt.Syntax in
    with_conn ~host ~port ~user ~password ~database (fun conn ->
        let version = migration.Omigrate.Migration.version in
        let* version_exists = version_exists ~conn version in
        if version_exists
        then
          Logs_lwt.info (fun m ->
              m "Version %Ld has already been applied" version)
        else
          let* () =
            Logs_lwt.info (fun m -> m "Applying up migration %Ld" version)
          in
          let* _ =
            Pgx_lwt_unix.simple_query conn migration.Omigrate.Migration.up
          in
          let* () =
            Logs_lwt.debug (fun m ->
                m "Inserting version %Ld in migration table" version)
          in
          Pgx_lwt_unix.execute_unit
            ~params:[ Pgx.Value.(of_int64 version) ]
            conn
            ("INSERT INTO " ^ quote_statement migrations_table ^ " VALUES ($1);"))
  ;;

  let down ~host ~port ~user ~password ~database migration =
    let open Lwt.Syntax in
    with_conn ~host ~port ~user ~password ~database (fun conn ->
        let version = migration.Omigrate.Migration.version in
        let* version_exists = version_exists ~conn version in
        if not version_exists
        then
          Logs_lwt.info (fun m -> m "Version %Ld has not been applied" version)
        else
          let* () =
            Logs_lwt.info (fun m -> m "Applying down migration %Ld" version)
          in
          let* _ =
            Pgx_lwt_unix.simple_query conn migration.Omigrate.Migration.down
          in
          let* () =
            Logs_lwt.debug (fun m ->
                m "Removing version %Ld from migration table" version)
          in
          Pgx_lwt_unix.execute_unit
            ~params:[ Pgx.Value.(of_int64 version) ]
            conn
            ("DELETE FROM "
            ^ quote_statement migrations_table
            ^ " WHERE version = $1;"))
  ;;

  let create ~host ~port ~user ~password database =
    let open Lwt.Syntax in
    let* () =
      with_conn ~host ~port ~user ~password (fun conn ->
          let* database_exists = database_exists ~conn database in
          if database_exists
          then Logs_lwt.info (fun m -> m "Database already exists")
          else
            let* () = Logs_lwt.info (fun m -> m "Creating the database") in
            Pgx_lwt_unix.execute_unit
              conn
              ("CREATE DATABASE " ^ quote_statement database ^ ";"))
    in
    with_conn ~host ~port ~user ~password ~database (fun conn ->
        ensure_version_table_exists ~conn)
  ;;

  let drop ~host ~port ~user ~password database =
    let open Lwt.Syntax in
    with_conn ~host ~port ~user ~password (fun conn ->
        let* database_exists = database_exists ~conn database in
        if not database_exists
        then Logs_lwt.info (fun m -> m "Database does not exists")
        else
          let* () = Logs_lwt.info (fun m -> m "Deleting the database") in
          Pgx_lwt_unix.execute_unit
            conn
            ("DROP DATABASE " ^ quote_statement database ^ ";"))
  ;;

  let versions ~host ~port ~user ~password ~database () =
    let open Lwt.Syntax in
    with_conn ~host ~port ~user ~password ~database (fun conn ->
        let* () = Logs_lwt.debug (fun m -> m "Querying all versions") in
        let+ result =
          Pgx_lwt_unix.execute
            conn
            ("SELECT version FROM " ^ quote_statement migrations_table ^ ";")
        in
        match result with
        | [] -> []
        | _ ->
          result |> List.map (fun row -> List.hd row |> Pgx.Value.to_int64_exn))
  ;;
end
