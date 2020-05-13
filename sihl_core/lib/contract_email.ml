module type EMAIL = sig
  type email

  val send : Opium.Std.Request.t -> email -> (unit, string) result Lwt.t

  (* val queue : Opium.Std.Request.t -> email -> (unit, string) result Lwt.t *)
end

module type REPOSITORY = sig
  (* TODO *)
end
