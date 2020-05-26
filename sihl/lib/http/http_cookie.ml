let set ~key ~data =
  Opium.Std.Cookie.set ~http_only:true ~secure:false ~key ~data

let unset ~key =
  Opium.Std.Cookie.set
    ~expiration:(`Max_age (Int64.of_int 0))
    ~http_only:true ~secure:false ~key ~data:"removed"

module Cookie_ = Opium.Std.Cookie
