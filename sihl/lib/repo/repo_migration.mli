module Model : sig
  val of_tuple : string * int * bool -> Core.Contract.Migration.State.t

  val to_tuple : Core.Contract.Migration.State.t -> string * int * bool
end

val execute :
  Core.Contract.Migration.migration list -> (unit, string) result Lwt.t

module Mariadb : sig
  val migrate :
    ?disable_fk_check:bool ->
    string ->
    (module Caqti_lwt.CONNECTION) ->
    unit Core.Db.db_result
end

module Postgresql : sig
  val migrate :
    string -> (module Caqti_lwt.CONNECTION) -> unit Core.Db.db_result
end
