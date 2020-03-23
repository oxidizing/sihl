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
  let isAdmin = Model.User.isAdmin;
  let id = Model.User.id;
  let fromJson = Model.User.t_decode;

  let authenticate = (conn, token) => {
    open! Sihl.Core.Http.Endpoint;
    let%Async tokenAssignment =
      Repository.Token.Get.query(conn, ~token)
      |> abortIfErr(Unauthorized("Not authorized"));
    let%Async user =
      Repository.User.Get.query(conn, ~userId=tokenAssignment.user)
      |> abortIfErr(Unauthorized("Not authorized"));
    Async.async(user);
  };

  let isTokenValid = (conn, token) => {
    open! Sihl.Core.Http.Endpoint;
    Repository.Token.Get.query(conn, ~token)->Async.mapAsync(_ => true);
  };

  let logout = ((conn, user: Model.User.t)) => {
    open! Sihl.Core.Http.Endpoint;
    let%Async _ =
      Repository.Token.DeleteForUser.query(
        conn,
        ~userId=user.id,
        ~kind="auth",
      );
    Async.async(user);
  };

  let getAll = ((conn, user)) => {
    open! Sihl.Core.Http.Endpoint;
    if (!Model.User.isAdmin(user)) {
      abort @@ Forbidden("Not allowed");
    };
    Repository.User.GetAll.query(conn);
  };

  let get = ((conn, user), ~userId) => {
    open! Sihl.Core.Http.Endpoint;
    if (!Model.User.isAdmin(user) && !Model.User.isOwner(user, userId)) {
      abort @@ Forbidden("Not allowed");
    };
    Repository.User.Get.query(conn, ~userId);
  };

  let login = (conn, ~email, ~password) => {
    open! Sihl.Core.Http.Endpoint;
    let%Async user = Repository.User.GetByEmail.query(conn, ~email);
    switch (user) {
    | Error(_) => abort @@ Unauthorized("Invalid password or email provided")
    | Ok(user) =>
      let%Async isSame =
        Sihl.Core.Bcrypt.Hash.compare(~plain=password, ~hash=user.password);
      if (!isSame) {
        abort @@ Unauthorized("Invalid password or email provided");
      };
      let token = Model.Token.generateAuth(~user);
      let%Async _ = Repository.Token.Upsert.query(conn, ~token);
      Async.async((user, token));
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

  let requestPasswordReset = (conn, ~email) => {
    open! Sihl.Core.Http.Endpoint;
    let%Async user = Repository.User.GetByEmail.query(conn, ~email);
    switch (user) {
    | Ok(user) =>
      let token = Model.Token.generatePasswordReset(~user);
      let%Async _ = Repository.Token.Upsert.query(conn, ~token);
      let email = Model.Email.PasswordReset.make(~token, ~user);
      Email.send(conn, ~email);
    | Error(_) =>
      // If no user was found, just send 200 ok to not expose user data
      Async.async()
    };
  };

  let resetPassword = (conn, ~token, ~newPassword) => {
    open! Sihl.Core.Http.Endpoint;
    let%Async token =
      Repository.Token.Get.query(conn, ~token)
      |> abortIfErr(Forbidden("Invalid token provided"));
    if (token.kind !== "password_reset") {
      abort @@ Forbidden("Invalid token provided");
    };
    let%Async user =
      Repository.User.Get.query(conn, ~userId=token.user)
      |> abortIfErr(Unauthorized("Invalid token provided"));
    let%Async hash =
      Sihl.Core.Bcrypt.hashAndSalt(~plain=newPassword, ~rounds=12);
    let user = {...user, password: hash};
    Repository.User.Upsert.query(conn, ~user);
  };

  let updatePassword =
      ((conn, user), ~userId, ~currentPassword, ~newPassword) => {
    open! Sihl.Core.Http.Endpoint;
    if (!Model.User.isOwner(user, userId)) {
      abort @@ Forbidden("Not allowed");
    };
    let%Async user =
      Repository.User.Get.query(conn, ~userId)
      |> abortIfErr(BadRequest("Invalid userId provided"));
    let%Async isSame =
      Sihl.Core.Bcrypt.Hash.compare(
        ~plain=currentPassword,
        ~hash=user.password,
      );
    if (!isSame) {
      abort @@ BadRequest("Current password doesn't match provided password");
    };
    let%Async hash =
      Sihl.Core.Bcrypt.hashAndSalt(~plain=newPassword, ~rounds=12);
    let user = {...user, password: hash};
    Repository.User.Upsert.query(conn, ~user);
  };

  let setPassword = ((conn, user), ~userId, ~newPassword) => {
    open! Sihl.Core.Http.Endpoint;
    if (!Model.User.isAdmin(user)) {
      abort @@ Forbidden("Not allowed");
    };
    let%Async user =
      Repository.User.Get.query(conn, ~userId)
      |> abortIfErr(BadRequest("Invalid userId provided"));
    let%Async hash =
      Sihl.Core.Bcrypt.hashAndSalt(~plain=newPassword, ~rounds=12);
    let user = {...user, password: hash};
    Repository.User.Upsert.query(conn, ~user);
  };

  let updateDetails =
      (
        (conn, user),
        ~userId,
        ~email,
        ~username,
        ~givenName,
        ~familyName,
        ~phone,
      ) => {
    open! Sihl.Core.Http.Endpoint;
    if (!Model.User.isAdmin(user) && !Model.User.isOwner(user, userId)) {
      abort @@ Forbidden("Not allowed");
    };
    let%Async user =
      Repository.User.Get.query(conn, ~userId)
      |> abortIfErr(BadRequest("Invalid userId provided"));
    let confirmed = email !== user.email ? false : true;
    let user = {
      ...user,
      email,
      username,
      givenName,
      familyName,
      phone,
      confirmed,
    };
    Repository.User.Upsert.query(conn, ~user);
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
    let%Async user = Repository.User.GetByEmail.query(conn, ~email);
    if (Belt.Result.isOk(user)) {
      abort @@ BadRequest("Email already taken");
    };
    let%Async hash =
      Sihl.Core.Bcrypt.hashAndSalt(~plain=password, ~rounds=12);
    let user =
      Model.User.make(
        ~email,
        ~username,
        ~password=hash,
        ~givenName,
        ~familyName,
        ~phone,
        ~admin=false,
      );
    switch (user) {
    | Ok(user) =>
      let%Async _ = Repository.User.Upsert.query(conn, ~user);
      let%Async _ =
        suppressEmail ? Async.async() : sendRegistrationEmail(conn, ~user);
      Async.async(user);
    | Error(msg) => abort(BadRequest(msg))
    };
  };

  let createAdmin =
      (conn, ~email, ~username, ~givenName, ~familyName, ~password) => {
    open! Sihl.Core.Http.Endpoint;
    let%Async user = Repository.User.GetByEmail.query(conn, ~email);
    if (Belt.Result.isOk(user)) {
      abort @@ BadRequest("Email already taken");
    };
    let%Async hash =
      Sihl.Core.Bcrypt.hashAndSalt(~plain=password, ~rounds=12);
    let user =
      Model.User.make(
        ~email,
        ~username,
        ~password=hash,
        ~givenName,
        ~familyName,
        ~phone=None,
        ~admin=true,
      );
    switch (user) {
    | Ok(user) =>
      Repository.User.Upsert.query(conn, ~user)->Async.mapAsync(_ => user)
    | Error(msg) => abort(BadRequest(msg))
    };
  };
};
