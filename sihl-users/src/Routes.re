let users: Sihl.Core.Http.Handler.t =
  _ =>
    Future.value(
      Sihl.Core.Http.Response.make(
        ~bodyJson=
          "All good"
          |> Sihl.Core.Http.Message.make
          |> Sihl.Core.Http.Message.encode,
        (),
      ),
    );

let user: Sihl.Core.Http.Handler.t =
  _ =>
    Future.value(
      Sihl.Core.Http.Response.make(
        ~bodyJson=
          "All good"
          |> Sihl.Core.Http.Message.make
          |> Sihl.Core.Http.Message.encode,
        (),
      ),
    );

let myUser: Sihl.Core.Http.Handler.t =
  _ =>
    Future.value(
      Sihl.Core.Http.Response.make(
        ~bodyJson=
          "All good"
          |> Sihl.Core.Http.Message.make
          |> Sihl.Core.Http.Message.encode,
        (),
      ),
    );

let register: Sihl.Core.Http.Handler.t =
  _ =>
    Future.value(
      Sihl.Core.Http.Response.make(
        ~bodyJson=
          "All good"
          |> Sihl.Core.Http.Message.make
          |> Sihl.Core.Http.Message.encode,
        (),
      ),
    );

let login: Sihl.Core.Http.Handler.t =
  _ =>
    Future.value(
      Sihl.Core.Http.Response.make(
        ~bodyJson=
          "All good"
          |> Sihl.Core.Http.Message.make
          |> Sihl.Core.Http.Message.encode,
        (),
      ),
    );

let auth: Sihl.Core.Http.Middleware.t =
  (handler, request) => {
    open Tablecloth;
    let isValidToken =
      request
      |> Sihl.Core.Http.Request.authToken
      |> Option.map(
           ~f=Sihl.Core.Jwt.isVerifyableToken(~secret=Config.jwtSecret),
         )
      |> Option.withDefault(~default=false);
    isValidToken
      ? handler(request)
      : Future.value(
          Sihl.Core.Http.Response.errorToResponse(
            `AuthenticationError("Not authenticated"),
          ),
        );
  };
