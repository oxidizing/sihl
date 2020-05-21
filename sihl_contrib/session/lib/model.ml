module Session = struct
  type t = { id : string; data : string; expire_date : Ptime.t }

  let create () = { id = "TODO"; data = "{}"; expire_date = Ptime_clock.now () }

  let key _ = "TODO"
end
