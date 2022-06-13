module Url = Test_url
module View = Test_view

let routes =
  [ Url.order_dispatch, View.order_dispatch
  ; Url.order_create, View.order_create
  ; Url.order_detail, View.order_detail
  ; Url.order_list, View.order_list
  ]
;;

let%test_unit "routes" = ()
