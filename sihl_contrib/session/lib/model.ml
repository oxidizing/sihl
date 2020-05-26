module Session = struct
  type t = { key : string; data : string; expire_date : Ptime.t }

  let one_week = 60 * 60 * 24 * 7

  let create () =
    {
      key = Sihl.Core.Random.base64 ~bytes:10;
      data = "{}";
      expire_date =
        one_week |> Ptime.Span.of_int_s
        |> Ptime.add_span (Ptime_clock.now ())
        |> Option.get;
    }

  let key session = session.key
end
