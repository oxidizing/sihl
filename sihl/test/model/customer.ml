type city =
  | Zurich
  | Bern
  | Basel
[@@deriving yojson]

type tier =
  | Premium
  | Top
  | Business
  | Standard
[@@deriving yojson]

type t =
  { id : int option
  ; user_id : int
  ; tier : tier
  ; street : string
  ; city : city
  ; created_at : Sihl.Model.Ptime.t
  ; updated_at : Sihl.Model.Ptime.t
  }
[@@deriving fields, yojson, make]

let schema =
  Sihl.Model.
    [ int ~primary_key:true Fields.id
    ; foreign_key "user" Fields.user_id
    ; enum tier_of_yojson tier_to_yojson Fields.tier
    ; string ~max_length:30 Fields.street
    ; enum city_of_yojson city_to_yojson Fields.city
    ; timestamp ~default:Now Fields.created_at
    ; timestamp ~default:Now ~update:true Fields.updated_at
    ]
;;

let validate (t : t) =
  match t.tier, t.city with
  | Standard, Zurich -> [ "A customer from Zurich can not have tier Standard" ]
  | Business, Basel -> [ "A customer from Basel can not have tier Business" ]
  | Premium, Bern -> [ "A customer from Bern can not have tier Premium" ]
  | _ -> []
;;

let t =
  Sihl.Model.create ~validate to_yojson of_yojson "customer" Fields.names schema
;;

let pp = Sihl.Model.pp t [@@ocaml.toplevel_printer]
let eq = Sihl.Model.eq t
