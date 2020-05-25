module Session = struct
  type t = { key : string; data : string; expire_date : Ptime.t }

  let create () =
    { key = "TODO"; data = "{}"; expire_date = Ptime_clock.now () }

  let key session = session.key
end
