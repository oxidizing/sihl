module Session = struct
  type t = { key : string; data : string; expire_date : Ptime.t }

  let one_week = 60 * 60 * 24 * 7

  let default_expiration_date () =
    match
      one_week |> Ptime.Span.of_int_s |> Ptime.add_span (Ptime_clock.now ())
    with
    | Some date -> date
    | None ->
        let msg = "SESSION APP: Setting default expiration went wrong" in
        Logs.err (fun m -> m "%s" msg);
        failwith msg

  let empty_data = "{}"

  let create () =
    {
      key = Sihl.Core.Random.base64 ~bytes:10;
      data = empty_data;
      expire_date = default_expiration_date ();
    }

  let key session = session.key
end
