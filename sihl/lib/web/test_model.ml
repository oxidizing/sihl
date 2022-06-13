module Order = struct
  type company =
    | Fedex
    | Ups
  [@@deriving yojson]

  type t =
    { order_date : Model.Ptime.t
    ; sipping_company : company
    ; description : string
    }
  [@@deriving yojson, fields]

  let schema =
    Model.
      [ timestamp Fields.order_date
      ; enum company_of_yojson company_to_yojson Fields.sipping_company
      ; string Fields.description
      ]
  ;;

  let t = Model.create to_yojson of_yojson "web_orders" Fields.names schema
end
