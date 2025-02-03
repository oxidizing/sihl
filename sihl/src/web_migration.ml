let log_src = Logs.Src.create "sihl.middleware.migration"

module Logs = (val Logs.src_log log_src : Logs.LOG)

exception Pending_migrations

let middleware pending_migrations =
  let filter handler req =
    let%lwt migrations = pending_migrations () in
    if List.length migrations > 0
    then (
      Logs.err (fun m ->
        m "There are %d pending migrations" (List.length migrations));
      Logs.info (fun m ->
        m "Run 'sihl migrate' to apply the pending migrations");
      if
        Core_configuration.is_production ()
        (* We try to make it work, even if the application makes wrong
           assumptions about the database schema. *)
      then handler req
      else raise Pending_migrations)
    else handler req
  in
  Rock.Middleware.create ~name:"migration" ~filter
;;
