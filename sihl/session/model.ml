exception Exception of string

module Map = Map.Make (String)

type data = string Map.t

type t =
  { key : string
  ; data : data
  ; expire_date : Ptime.t
  }

let sexp_of_t { key; expire_date; _ } =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  List
    [ List [ Atom "key"; sexp_of_string key ]
    ; List [ Atom "expire_date"; sexp_of_string (Ptime.to_rfc3339 expire_date) ]
    ]
;;

(* TODO [jerben] Consider moving date stuff into Utils.Time *)
let one_week = 60 * 60 * 24 * 7
let default_expiration_date now = one_week |> Ptime.Span.of_int_s |> Ptime.add_span now
let key session = session.key
let data session = session.data
let is_expired now session = Ptime.is_later now ~than:session.expire_date

type data_map = (string * string) list [@@deriving yojson]

let string_of_data data =
  data |> Map.to_seq |> List.of_seq |> data_map_to_yojson |> Yojson.Safe.to_string
;;

let data_of_string str =
  str
  |> Yojson.Safe.from_string
  |> data_map_of_yojson
  |> Result.map List.to_seq
  |> Result.map Map.of_seq
;;

type map = (string * string) list [@@deriving yojson]

let get key session = Map.find_opt key session.data
let set ~key ~value session = { session with data = Map.add key value session.data }
let remove ~key session = { session with data = Map.remove key session.data }

let pp ppf { key; data; _ } =
  Caml.Format.fprintf ppf "key: %s data: %s " key (string_of_data data)
;;

let t =
  let encode m =
    let data = m.data |> string_of_data in
    Ok (m.key, data, m.expire_date)
  in
  let decode (key, data, expire_date) =
    match data |> data_of_string with
    | Ok data -> Ok { key; data; expire_date }
    | Error msg -> Error msg
  in
  Caqti_type.(custom ~encode ~decode (tup3 string string ptime))
;;
