module type SERVICE = sig
  val send :
    Opium.Std.Request.t -> Email_model.t -> (unit, string) Result.t Lwt.t
end
