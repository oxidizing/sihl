module Map = Map.Make (String)

type data = string Map.t

type t =
  { key : string
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

let expiration_date now = Sihl_core.Time.date_from_now now Sihl_core.Time.OneWeek
let key session = session.key
let is_expired now session = Ptime.is_later now ~than:session.expire_date
