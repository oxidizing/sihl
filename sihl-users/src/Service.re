module Async = Sihl.Core.Async;

module User = {
  let authenticate = (conn, header) => {
    let tokenString = header |> Model.Token.fromHeader |> Belt.Option.getExn;
    let%Async token = Repository.Token.Get.query(conn, ~tokenString);
    Repository.User.Get.query(conn, ~userId=token.userId);
  };

  let getAll = conn => {
    Repository.User.GetAll.query(conn);
  };

  let login = (conn, ~email, ~password) => {
    open! Sihl.Core.Http.Endpoint;
    let%Async user = Repository.User.GetByEmail.query(conn, ~email);
    if (!Sihl.Core.Bcrypt.Hash.compareSync(password, user.password)) {
      abort @@ Unauthorized("Invalid password or email provided");
    };
    let token = Model.Token.generate(~user);
    let%Async _ = Repository.Token.Store.query(conn, ~token);
    Async.async(token);
  };

  let register =
      (conn, ~email, ~username, ~password, ~givenName, ~familyName, ~phone) => {
    open! Sihl.Core.Http.Endpoint;
    let user =
      abortIfError(
        Model.User.make(
          ~email,
          ~username,
          ~password=Sihl.Core.Bcrypt.hashAndSaltSync(~rounds=12, password),
          ~givenName,
          ~familyName,
          ~phone,
        ),
      );
    let%Async _ = Repository.User.Store.query(conn, ~user);
    Async.async(user);
  };
};

module Permission = {
  let has = (conn, user, perm) => {
    Repository.Permission.Has.query(conn, ~user, ~perm);
  };

  let ensure = (conn, header, perm) => {
    open! Sihl.Core.Http.Endpoint;
    let%Async user = User.authenticate(conn, header);
    let%Async isAllowed = has(conn, user, perm);
    if (!isAllowed) {
      abort @@ Forbidden("Not allowed");
    };
    Async.async(user);
  };
};
