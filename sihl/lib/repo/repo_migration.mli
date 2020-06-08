module Model : sig
  val of_tuple : string * int * bool -> Core.Contract.Migration.State.t

  val to_tuple : Core.Contract.Migration.State.t -> string * int * bool
end

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
