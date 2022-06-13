let order_dispatch =
  View.form
    ~on_invalid:(fun request _ ->
      Lwt.return
      @@ Dream.add_flash_message request "error" "Please fix the errors below")
    (fun request (data : Test_form.Order_dispatch.t) ->
      print_endline @@ Format.sprintf "Order %s dispatched" data.description;
      Lwt.return
      @@ Dream.add_flash_message request View.message_success "Order dispatched")
    (fun _ -> View.reverse Test_url.order_list)
    Test_form.order_dispatch
    Test_template.order_dispatch
;;

let order_create = View.create ()
let order_list = View.list ()
let order_details = View.details ()
