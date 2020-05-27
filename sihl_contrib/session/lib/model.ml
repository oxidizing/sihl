open Base

module Session = struct
  type data = (string, string, String.comparator_witness) Map.t

  type t = { key : string; data : data; expire_date : Ptime.t }

  let one_week = 60 * 60 * 24 * 7

  let default_expiration_date now =
    match one_week |> Ptime.Span.of_int_s |> Ptime.add_span now with
    | Some date -> date
    | None ->
        let msg = "SESSION APP: Setting default expiration went wrong" in
        Logs.err (fun m -> m "%s" msg);
        failwith msg

  let create now =
    {
      key = Sihl.Core.Random.base64 ~bytes:10;
      data = Map.empty (module String);
      expire_date = default_expiration_date now;
    }

  let key session = session.key

  let data session = session.data

  let is_expired now session = Ptime.is_later session.expire_date ~than:now

  type data_map = (string * string) list [@@deriving yojson]

  let string_of_data data =
    data |> Map.to_alist |> data_map_to_yojson |> Yojson.Safe.to_string

  let data_of_string str =
    str |> Yojson.Safe.from_string |> data_map_of_yojson
    |> Result.map ~f:(Map.of_alist_exn (module String))

  type map = (string * string) list [@@deriving yojson]

  let get key session = Map.find session.data key

  let set ~key ~value session =
    { session with data = Map.set ~key ~data:value session.data }

  let pp ppf { key; data; _ } =
    Caml.Format.fprintf ppf "key: %s data: %s " key (string_of_data data)
end
