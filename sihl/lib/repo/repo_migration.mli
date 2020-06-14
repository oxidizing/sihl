val get_repo_by_database : unit -> (module Core.Contract.Migration.REPOSITORY)

val execute :
  Core.Contract.Migration.migration list -> (unit, string) result Lwt.t

module Mariadb : sig
  val set_fk_check : Core.Db.db_connection -> bool -> unit Core.Db.db_result

  val migrate :
    ?disable_fk_check:bool ->
    string ->
    Core.Db.db_connection ->
    unit Core.Db.db_result
end

module Postgresql : sig
  val migrate : string -> Core.Db.db_connection -> unit Core.Db.db_result
end
