module Order = Test_model.Order
module Model = Sihl__model.Model
module Form = Sihl__form.Form

module Order_dispatch = struct
  type t =
    { order_id : int
    ; dispatch_date : Model.Ptime.t
    ; description : string
    }
  [@@deriving yojson, fields]

  let schema =
    Form.
      [ int Fields.order_id
      ; timestamp Fields.dispatch_date
      ; string ~widget:TextArea Fields.description
      ]
  ;;

  let t = Form.create to_yojson of_yojson "order_dispatch" Fields.names schema
end

let order_dispatch = Order_dispatch.t

let order =
  Form.of_model ~widgets:[ Form.text_area Order.Fields.description ] Order.t
;;
