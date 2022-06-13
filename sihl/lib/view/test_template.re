open Tyxml;

let order_dispatch = (request: Dream.request, form: Form.t(_)) =>
  <html>
    <head> <title> {Html.txt("Hello")} </title> </head>
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

let order_list = Obj.magic();
