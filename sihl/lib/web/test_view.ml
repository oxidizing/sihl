module Url = Test_url
module Form = Test_form
module Template = Test_template

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
