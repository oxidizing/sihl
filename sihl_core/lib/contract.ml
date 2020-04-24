module type EMAILTRANSPORT = sig
  val send : Email_core.t -> (unit, string) result Lwt.t
end
