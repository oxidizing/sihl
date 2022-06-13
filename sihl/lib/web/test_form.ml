module Order = Test_model.Order

module Order_dispatch = struct
  type t =
    { order_id : int
    ; dispatch_date : Model.Ptime.t
    ; description : string
    }
  [@@deriving yojson, fields]

  let schema =
    Web.Form.
      [ int Fields.order_id
      ; timestamp Fields.dispatch_date
      ; string ~widget:TextArea Fields.description
      ]
  ;;

  let t =
    Web.Form.create to_yojson of_yojson "order_dispatch" Fields.names schema
  ;;
end

let order_dispatch = Order_dispatch.t

let order =
  Web.Form.of_model
    ~widgets:[ Order.Fields.description, Web.Form.TextArea ]
    Order.t
;;
