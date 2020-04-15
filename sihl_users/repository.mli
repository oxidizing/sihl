module User : sig
  val get_all : Opium.Std.Request.t -> (Model.User.t list, string) Lwt_result.t
  val get : Opium.Std.Request.t -> id:string -> (Model.User.t, string) Lwt_result.t
  val get_by_email : Opium.Std.Request.t -> email:string -> (Model.User.t, string) Lwt_result.t
  val insert : Opium.Std.Request.t -> Model.User.t -> (unit, string) Lwt_result.t
  val update : Opium.Std.Request.t -> Model.User.t -> (unit, string) Lwt_result.t
end

module Token : sig
  val get : Opium.Std.Request.t -> value:string -> (Model.Token.t, string) Lwt_result.t
  val delete_by_user : Opium.Std.Request.t -> id:string -> (unit, string) Lwt_result.t
  val insert : Opium.Std.Request.t -> Model.Token.t -> (unit, string) Lwt_result.t
  val update : Opium.Std.Request.t -> Model.Token.t -> (unit, string) Lwt_result.t
end
