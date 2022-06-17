module User = Sihl__user.User
module Model = Sihl__model.Model

module Order = struct
  type company =
    | Fedex
    | Ups
  [@@deriving yojson, enumerate]

  type t =
    { order_date : Model.Ptime.t
    ; company : company
    ; description : string
    }
  [@@deriving yojson, fields]

  let schema =
    Model.
      [ timestamp Fields.order_date
      ; enum all_of_company company_of_yojson company_to_yojson Fields.company
      ; string Fields.description
      ]
  ;;

  let t = Model.create to_yojson of_yojson "web_orders" Fields.names schema
  let is_owner (_ : User.t) : bool Lwt.t = Lwt.return true
end
