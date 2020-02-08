let (<$>) = Future.(<$>);
let (>>=) = Future.(>>=);

let getUsers = (pool, _) => {
  pool
  |> Sihl.Core.Db.Pool.connect
  >>= Repository.User.GetAll.query
  <$> Model.Users.encode
  |> Sihl.Core.Http.respond;
};

let getUser = (pool, request) => {
  Future.mapOk2(
    Future.value(Sihl.Core.Http.Request.param("userId", request)),
    pool |> Sihl.Core.Db.Pool.connect,
    (userId, connection) =>
    (userId, connection)
  )
  >>= (
    ((userId, connection)) => Repository.User.Get.query(connection, ~userId)
  )
  <$> Model.User.encode
  |> Sihl.Core.Http.respond;
};

let getMyUser: Sihl.Core.Http.Handler.t =
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

let requestPasswordReset: Sihl.Core.Http.Handler.t =
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

let resetPassword: Sihl.Core.Http.Handler.t =
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

let updatePassword: Sihl.Core.Http.Handler.t =
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

let setPassword: Sihl.Core.Http.Handler.t =
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
      |> Option.map(~f=Sihl.Core.Jwt.isVerifyableToken(~secret="ABC"))
      |> Option.withDefault(~default=false);
    isValidToken
      ? handler(request)
      : Future.value(
          Sihl.Core.Http.Response.errorToResponse(
            `AuthenticationError("Not authenticated"),
          ),
        );
  };
