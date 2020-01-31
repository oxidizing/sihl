let register: ExpressHttp.Http.Handler.t =
  request =>
    Future.value(
      ExpressHttp.Response.make(
        ~bodyJson=
          "All good"
          |> Sihl.Core.Http.Message.make
          |> Sihl.Core.Http.Message.encode,
        (),
      ),
    );

let login: ExpressHttp.Http.Handler.t =
  request =>
    Future.value(
      ExpressHttp.Response.make(
        ~bodyJson=
          "All good"
          |> Sihl.Core.Http.Message.make
          |> Sihl.Core.Http.Message.encode,
        (),
      ),
    );
