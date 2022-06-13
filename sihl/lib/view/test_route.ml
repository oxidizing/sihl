module Url = Test_url
module View = Test_view

let routes =
  [ View.order_dispatch Url.order_dispatch
  ; View.order_create Url.order_create
  ; View.order_details Url.order_details
  ; View.order_list Url.order_list
  ]
;;

let%test_unit "routes" = ()
