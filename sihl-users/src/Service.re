module Async = Sihl.Core.Async;

module User = {
  let authenticate = (conn, token) => {
    open! Sihl.Core.Http.Endpoint;
    let%Async tokenAssignment =
      Repository.Token.Get.query(conn, ~token)
      |> abortIfErr(Forbidden("Not authorized"));
    let%Async user =
      Repository.User.Get.query(conn, ~userId=tokenAssignment.user)
      |> abortIfErr(Forbidden("Not authorized"));
    Async.async(user);
  };

  let getAll = conn => {
    Repository.User.GetAll.query(conn);
  };

  let login = (conn, ~email, ~password) => {
    open! Sihl.Core.Http.Endpoint;
    let%Async user = Repository.User.GetByEmail.query(conn, ~email);
    switch (user) {
    | Belt.Result.Error(_) =>
      abort @@ Unauthorized("Invalid password or email provided")
    | Belt.Result.Ok(user) =>
      if (!Sihl.Core.Bcrypt.Hash.compareSync(password, user.password)) {
        abort @@ Unauthorized("Invalid password or email provided");
      };
      let token = Model.Token.generate(~user);
      let%Async _ = Repository.Token.Store.query(conn, ~token);
      Async.async(token);
    };
  };

  let register =
      (conn, ~email, ~username, ~password, ~givenName, ~familyName, ~phone) => {
    open! Sihl.Core.Http.Endpoint;
    let user =
      Model.User.make(
        ~email,
        ~username,
        ~password=Sihl.Core.Bcrypt.hashAndSaltSync(~rounds=12, password),
        ~givenName,
        ~familyName,
        ~phone,
        ~admin=false,
      );
    switch (user) {
    | Belt.Result.Ok(user) =>
      Repository.User.Store.query(conn, ~user)->Async.mapAsync(_ => user)
    | Belt.Result.Error(msg) => abort(BadRequest(msg))
    };
  };

  let createAdmin = (conn, ~email, ~username, ~password) => {
    open! Sihl.Core.Http.Endpoint;
    let user =
      Model.User.make(
        ~email,
        ~username,
        ~password=Sihl.Core.Bcrypt.hashAndSaltSync(~rounds=12, password),
        ~givenName="",
        ~familyName="",
        ~phone=None,
        ~admin=true,
      );
    switch (user) {
    | Belt.Result.Ok(user) =>
      Repository.User.Store.query(conn, ~user)->Async.mapAsync(_ => user)
    | Belt.Result.Error(msg) => abort(BadRequest(msg))
    };
  };
};
