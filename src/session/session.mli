module Schedule = Session_schedule

type data_map = Session_model.data_map

type data = Session_model.data

type t = Session_model.t

val create : ?expire_date:Ptime.t -> Ptime.t -> t

val key : t -> string

val add_to_ctx : t -> Core.Ctx.t -> Core.Ctx.t

val data : t -> (string, string, Base.String.comparator_witness) Base.Map.t

val is_expired : Ptime.t -> t -> bool

val data_of_string : string -> (data, string) Result.t

val string_of_data : data -> string

val get : string -> t -> string option

val set : key:string -> value:string -> t -> t

val remove : key:string -> t -> t

val pp : Format.formatter -> t -> unit

val t : t Caqti_type.t

val set_value :
  Core.Ctx.t -> key:string -> value:string -> (unit, string) Result.t Lwt.t

val remove_value : Core.Ctx.t -> key:string -> (unit, string) Result.t Lwt.t

val get_value :
  Core.Ctx.t -> key:string -> (string option, string) Result.t Lwt.t

val get_session :
  Core.Ctx.t -> key:string -> (Session_model.t option, string) Result.t Lwt.t

val insert_session :
  Core.Ctx.t -> session:Session_model.t -> (unit, string) Result.t Lwt.t

module Sig = Session_sig
module Service = Session_service
