module Async = Sihl.Core.Async;

module Email = {
  let devInbox = ref(None);

  let getLastEmail = () => devInbox^;

  let send = (_, ~email) => {
    // TODO use type safe GADTs
    let backend = Sihl.Core.Config.get("EMAIL_BACKEND");
    if (backend === "SMTP") {
      Async.async();
    } else {
      devInbox := Some(email);
      // TODO log based on config
      /* Async.async @@ Sihl.Core.Log.info(Model.Email.toString(email), ()); */
      Async.async();
    };
  };
};

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
      let token = Model.Token.generateAuth(~user);
      let%Async _ = Repository.Token.Upsert.query(conn, ~token);
      Async.async(token);
    };
  };

  let sendRegistrationEmail = (conn, ~user) => {
    let token = Model.Token.generateEmailConfirmation(~user);
    let%Async _ = Repository.Token.Upsert.query(conn, ~token);
    let email = Model.Email.EmailConfirmation.make(~token, ~user);
    Email.send(conn, ~email);
  };

  let confirmEmail = (conn, ~token) => {
    open! Sihl.Core.Http.Endpoint;
    let%Async token =
      Repository.Token.Get.query(conn, ~token)
      |> abortIfErr(Forbidden("Not authorized"));
    if (!Model.Token.isEmailConfirmation(token)) {
      abort @@ Unauthorized("Invalid token provided");
    };
    let%Async _ =
      Repository.Token.Upsert.query(
        conn,
        ~token={...token, status: "inactive"},
      );
    let%Async user =
      Repository.User.Get.query(conn, ~userId=token.user)
      |> abortIfErr(Unauthorized("Invalid token provided"));
    Repository.User.Upsert.query(conn, ~user={...user, confirmed: true});
  };

  let register =
      (
        conn,
        ~email,
        ~username,
        ~password,
        ~givenName,
        ~familyName,
        ~phone,
        ~suppressEmail=false,
        (),
      ) => {
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
      let%Async _ = Repository.User.Upsert.query(conn, ~user);
      let%Async _ =
        suppressEmail ? Async.async() : sendRegistrationEmail(conn, ~user);
      Async.async(user);
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
      Repository.User.Upsert.query(conn, ~user)->Async.mapAsync(_ => user)
    | Belt.Result.Error(msg) => abort(BadRequest(msg))
    };
  };
};
