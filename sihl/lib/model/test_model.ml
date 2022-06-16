module Customer = struct
  type city =
    | Zurich
    | Bern
    | Basel
  [@@deriving yojson, enumerate]

  type tier =
    | Premium
    | Top
    | Business
    | Standard
  [@@deriving yojson, enumerate]

  type t =
    { user_id : int
    ; tier : tier
    ; street : string
    ; city : city
    ; created_at : Model.Ptime.t
    ; updated_at : Model.Ptime.t
    }
  [@@deriving fields, yojson, make]

  let schema =
    Model.
      [ foreign_key Cascade "users" Fields.user_id
      ; enum all_of_tier tier_of_yojson tier_to_yojson Fields.tier
      ; string ~max_length:30 Fields.street
      ; enum all_of_city city_of_yojson city_to_yojson Fields.city
      ; timestamp ~default:Now Fields.created_at
      ; timestamp ~default:Now ~update:true Fields.updated_at
      ]
  ;;

  let validate (t : t) =
    match t.tier, t.city with
    | Standard, Zurich ->
      [ "A customer from Zurich can not have tier Standard" ]
    | Business, Basel -> [ "A customer from Basel can not have tier Business" ]
    | Premium, Bern -> [ "A customer from Bern can not have tier Premium" ]
    | _ -> []
  ;;

  let t =
    Model.create ~validate to_yojson of_yojson "customers" Fields.names schema
  ;;

  let pp = Model.pp t [@@ocaml.toplevel_printer]
  let eq = Model.eq t
end

module Order = struct
  type t =
    { customer_id : int
    ; description : string
    ; created_at : Model.Ptime.t
    ; updated_at : Model.Ptime.t
    }
  [@@deriving fields, yojson]

  let schema =
    Model.
      [ foreign_key Cascade "customers" Fields.customer_id
      ; string ~max_length:255 Fields.description
      ; timestamp ~default:Now Fields.created_at
      ; timestamp ~default:Now ~update:true Fields.updated_at
      ]
  ;;

  let t = Model.create to_yojson of_yojson "orders" Fields.names schema
end
