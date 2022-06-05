let%test "validate customer model" =
  let customer : Customer.t =
    Customer.
      { id = 1
      ; user_id = 1
      ; tier = Premium
      ; street = "Somestreet"
      ; city = Zurich
      ; created_at = Ptime_clock.now ()
      ; updated_at = Ptime_clock.now ()
      }
  in
  match Sihl.Model.validate Customer.t customer with
  | [], [] -> true
  | _ -> false
;;

let%test "validate customer model field" =
  let customer : Customer.t =
    Customer.
      { id = 1
      ; user_id = 1
      ; tier = Standard
      ; street =
          "A veryveryveryveryveryveryveryveryveryveryveryveryveryvery long \
           street name"
      ; city = Zurich
      ; created_at = Ptime_clock.now ()
      ; updated_at = Ptime_clock.now ()
      }
  in
  match Sihl.Model.validate Customer.t customer with
  | ( [ "A customer from Zurich can not have tier Standard" ]
    , [ ( "street"
        , [ Sihl.Model.
              { message = "field %s is too long"
              ; code = Some "too long"
              ; params = [ ("field", "street") ]
              }
          ] )
      ] ) -> true
  | _ -> false
;;
