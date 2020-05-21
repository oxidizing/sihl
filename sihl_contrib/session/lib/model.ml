module Session = struct
  type t = { id : string; data : string; expire_date : Ptime.t }
end
