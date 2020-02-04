let register: Http.Http.Handler.t =
  request =>
    Future.value(
      Http.Response.make(
        ~bodyJson=
          "All good"
          |> Sihl.Core.Http.Message.make
          |> Sihl.Core.Http.Message.encode,
        (),
      ),
    );

let login: Http.Http.Handler.t =
  request =>
    Future.value(
      Http.Response.make(
        ~bodyJson=
          "All good"
          |> Sihl.Core.Http.Message.make
          |> Sihl.Core.Http.Message.encode,
        (),
      ),
    );

let auth: Http.Http.Middleware.t =
  (handler, request) => {
    open Tablecloth;
    let isValidToken =
      request
      |> Http.Request.authToken
      |> Option.map(
           ~f=Sihl.Core.Jwt.isVerifyableToken(~secret=Config.jwtSecret),
         )
      |> Option.withDefault(~default=false);
    isValidToken
      ? handler(request)
      : Future.value(
          Http.Response.errorToResponse(
            `AuthenticationError("Not authenticated"),
          ),
        );
  };
