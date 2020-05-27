open Base

module Session = struct
  type data_map = (string * string) list [@@deriving yojson]

  type t = {
    key : string;
    data : (string, string, String.comparator_witness) Map.t;
    expire_date : Ptime.t;
  }

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

  let empty_data = {json| [] |json}

  let create () =
    {
      key = Sihl.Core.Random.base64 ~bytes:10;
      data = Map.empty (module String);
      expire_date = default_expiration_date ();
    }

  let key session = session.key

  let data session = session.data

  type map = (string * string) list [@@deriving yojson]

  let get key session = Map.find session.data key

  let set ~key ~value session =
    { session with data = Map.set ~key ~data:value session.data }
end
