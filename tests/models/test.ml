let%test_unit "validate customer model" =
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
  [%test_result: Sihl.Model.model_validation]
    (Sihl.Model.validate Customer.t customer)
    ~expect:([], [])
;;

let%test_unit "validate customer model field" =
  let customer : Customer.t =
    Customer.
      { id = 1
      ; user_id = 1
      ; tier = Premium
      ; street =
          "A veryveryveryveryveryveryveryveryveryveryveryveryveryvery long \
           street name"
      ; city = Zurich
      ; created_at = Ptime_clock.now ()
      ; updated_at = Ptime_clock.now ()
      }
  in
  [%test_result: Sihl.Model.model_validation]
    (Sihl.Model.validate Customer.t customer)
    ~expect:
      ( []
      , [ ( "street"
          , [ Sihl.Model.
                { message = "field %s is too long"
                ; code = Some "too long"
                ; params = [ "field", "street" ]
                }
            ] )
        ] )
;;
