open Tyxml;
module Form = Sihl__form.Form;

let order_dispatch = (request: Dream.request, _, form: Form.t(_)) =>
  <html>
    <head> <title> {Html.txt("Dispatch")} </title> </head>
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

let order_create = (request: Dream.request, _, form: Form.t(_)) =>
  <html>
    <head> <title> {Html.txt("Create")} </title> </head>
    <body>
      <div>
        <form method=`Post>
          {Html.Unsafe.data(Dream.csrf_tag(request))}
          {Form.render(form)}
          <button type_="submit"> {Html.txt("Create")} </button>
          <input type_="email" name="email" required="" value="foo" />
        </form>
      </div>
    </body>
  </html>;

let order_list = (_, _, orders: list(Test_model.Order.t)) =>
  <html>
    <head> <title> {Html.txt("Orders")} </title> </head>
    <body>
      <div>
        ...{List.map(
          (order: Test_model.Order.t) =>
            <span> {Html.txt(order.description)} </span>,
          orders,
        )}
      </div>
    </body>
  </html>;

let order_detail = (_, _, o: Test_model.Order.t) =>
  <html>
    <head> <title> {Html.txt("Detail")} </title> </head>
    <body> <div> <div> {Html.txt(o.description)} </div> </div> </body>
  </html>;
