type t =
  { id : int
  ; customer_id : int
  ; description : string
  ; created_at : Sihl.Model.Ptime.t
  ; updated_at : Sihl.Model.Ptime.t
  }
[@@deriving fields, yojson]

let schema =
  Sihl.Model.
    [ int ~primary_key:true Fields.id
    ; foreign_key "customer" Fields.customer_id
    ; string ~max_length:255 Fields.description
    ; timestamp ~default:Now Fields.created_at
    ; timestamp ~default:Now ~update:true Fields.updated_at
    ]
;;

let t = Sihl.Model.create to_yojson of_yojson "order" Fields.names schema
