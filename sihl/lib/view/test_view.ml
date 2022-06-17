module User = Sihl__user.User
module View = Sihl__view.View
module Query = Sihl__query.Query

let order_dispatch =
  User.login_required ~login_url:Test_url.login
  @@ View.form
       ~on_invalid:(fun request _ ->
         Lwt.return
         @@ Dream.add_flash_message
              request
              "error"
              "Please fix the errors below")
       (fun request (data : Test_form.Order_dispatch.t) ->
         print_endline @@ Format.sprintf "Order %s dispatched" data.description;
         Lwt.return
         @@ Dream.add_flash_message
              request
              View.message_success
              "Order dispatched")
       (fun _ -> Lwt.return @@ View.reverse Test_url.order_list)
       Test_form.order_dispatch
       Test_template.order_dispatch
;;

let order_create =
  User.login_required ~login_url:Test_url.login
  @@ View.create
       Test_model.Order.t
       (fun _ -> Lwt.return @@ View.reverse Test_url.order_list)
       Test_template.order_create
;;

let order_list =
  User.login_required ~login_url:Test_url.login
  @@ View.list ~query:(Query.all Test_model.Order.t) Test_template.order_list
;;

let order_detail =
  User.login_required ~login_url:Test_url.login
  @@ User.passes_test ~test:Test_model.Order.is_owner
  @@ View.detail ~model:Test_model.Order.t Test_template.order_detail
;;
