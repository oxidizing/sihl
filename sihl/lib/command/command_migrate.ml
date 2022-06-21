open Command_pure
module M = Minicli.CLI
module Config = Sihl__config.Config
module Migration = Sihl__migration.Migration

let fn args =
  let print_only = M.get_set_bool args [ "-p"; "--print" ] in
  M.finalize ();
  let path = Filename.concat (Config.root_path ()) "migrations" in
  if not (CCIO.File.exists path)
  then failwith "directory migrations does not exist, is this a Sihl project?"
  else if print_only
  then (
    let up, down = Migration.sql () in
    print_endline "up ------\n";
    print_endline up;
    print_endline "\n\ndown ------\n\n";
    print_endline down)
  else Lwt_main.run (Migration.generate path)
;;

let down : t =
  { name = "migrate.down"
  ; description = "Revert last migration"
  ; usage = "sihl migrate.down"
  ; fn
  ; stateful = false
  }
;;

let gen : t =
  { name = "migrate.gen"
  ; description = "Generate CREATE TABLE migrations from models"
  ; usage = "sihl migrate.gen"
  ; fn
  ; stateful = true
  }
;;

let t : t =
  { name = "migrate"
  ; description = "Run migrations"
  ; usage = "sihl migrate"
  ; fn
  ; stateful = false
  }
;;
