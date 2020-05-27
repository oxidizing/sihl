open Base

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

  let empty_data = {json| [] |json}

  let create () =
    {
      key = Sihl.Core.Random.base64 ~bytes:10;
      data = empty_data;
      expire_date = default_expiration_date ();
    }

  let key session = session.key

  let data session = session.data

  type map = (string * string) list [@@deriving yojson]

  let get key session =
    session.data |> Sihl.Core.Json.parse_opt
    |> Option.map ~f:map_of_yojson
    |> Option.map ~f:Result.ok_or_failwith
    |> Option.map ~f:(Map.of_alist_exn (module String))
    |> Option.bind ~f:(fun map -> Map.find map key)

  let set ~key ~value session =
    {
      session with
      data =
        session.data |> Sihl.Core.Json.parse_exn |> map_of_yojson
        |> Result.ok_or_failwith
        |> Map.of_alist_exn (module String)
        |> Map.set ~key ~data:value |> Map.to_alist |> map_to_yojson
        |> Yojson.Safe.to_string;
    }
end
