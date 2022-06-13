open Tyxml;

let order_dispatch = (request: Dream.request, form: Form.t(_)) =>
  <html>
    <head> <title> {Html.txt("Order dispatch")} </title> </head>
    <body>
      <div>
        <form method=`Post>
          {Html.Unsafe.data(Dream.csrf_tag(request))}
          {Form.render(form)}
          <button type_="submit"> {Html.txt("Dispatch")} </button>
        </form>
      </div>
    </body>
  </html>;

let order_create = (request: Dream.request, form: Form.t(_)) =>
  <html>
    <head> <title> {Html.txt("Order create")} </title> </head>
    <body>
      <div>
        <form method=`Post>
          {Html.Unsafe.data(Dream.csrf_tag(request))}
          {Form.render(form)}
          <button type_="submit"> {Html.txt("Create")} </button>
        </form>
      </div>
    </body>
  </html>;

let order_list = Obj.magic();

let order_detail = (_: Dream.request, o: Test_model.Order.t) =>
  <html>
    <head> <title> {Html.txt("Order detail")} </title> </head>
    <body> <div> <div> {Html.txt(o.description)} </div> </div> </body>
  </html>;
