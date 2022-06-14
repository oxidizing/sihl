module Url = Test_url

let routes =
  [ View.route Url.order_dispatch Test_view.order_dispatch
  ; View.route Url.order_create Test_view.order_create
  ; View.route Url.order_detail Test_view.order_detail
  ; View.route Url.order_list Test_view.order_list
  ]
;;

let%test_unit "routes" = ()
