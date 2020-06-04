module Model : sig
  val of_tuple : string * int * bool -> Core.Contract.Migration.State.t

  val to_tuple : Core.Contract.Migration.State.t -> string * int * bool
end

val execute :
  Core.Contract.Migration.migration list -> (unit, string) result Lwt.t
