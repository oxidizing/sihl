module Form = Test_form

module Template = struct
  let order_form = Obj.magic ()
  let order_list = Obj.magic ()
end

module Url = struct
  let order_dispatch = "/orders/:id/dispatch"
  let order_create = "/orders/new"
  let order_list = "/orders"
  let order_details = "/orders/:id"
end

module View = struct
  let order_dispatch =
    Web.View.form
      ~success_url:(fun _ -> Web.reverse Url.order_list)
      ~on_valid:(fun request _ ->
        (* process form.data *)
        Lwt.return @@ Dream.add_flash_message request "success" "Order created")
      ~on_invalid:(fun request _ ->
        Lwt.return
        @@ Dream.add_flash_message
             request
             "error"
             "Please correct the input fields below")
      Form.order_dispatch
      Template.order_form
  ;;

  let order_create = Web.View.create ()
  let order_list = Web.View.list Template.order_form
  let order_details = Web.View.details ()
end

let routes =
  [ View.order_dispatch Url.order_dispatch
  ; View.order_create Url.order_create
  ; View.order_details Url.order_details
  ; View.order_list Url.order_list
  ]
;;

let%test_unit "routes" = ()
