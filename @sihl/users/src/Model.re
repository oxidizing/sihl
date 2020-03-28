module User = {
  [@decco]
  type t = {
    id: string,
    email: string,
    username: string,
    password: string,
    [@decco.key "given_name"]
    givenName: string,
    [@decco.key "family_name"]
    familyName: string,
    phone: option(string),
    status: string,
    admin: Sihl.Core.Db.Bool.t,
    confirmed: Sihl.Core.Db.Bool.t,
  };

  let make =
      (~email, ~username, ~password, ~givenName, ~familyName, ~phone, ~admin) => {
    let id = Sihl.Core.Uuid.V4.uuidv4();
    Ok({
      id,
      email,
      username,
      password,
      givenName,
      familyName,
      phone,
      status: "active",
      admin,
      confirmed: false,
    });
  };

  let isAdmin = user => user.admin;
  let id = user => user.id;
  let isOwner = (user, id) => user.id === id;
};

module Token = {
  // TODO add expiration date
  [@decco]
  type t = {
    kind: string,
    id: string,
    user: string,
    token: string,
    status: string,
  };

  let setCookieHeader = token => (
    "set-cookie",
    {j|session=$(token); HttpOnly;|j},
  );

  let generateAuth = (~user: User.t) => {
    kind: "auth",
    id: Sihl.Core.Uuid.V4.uuidv4(),
    user: user.id,
    // TODO replace with proper token generation
    token: Sihl.Core.Uuid.V4.uuidv4(),
    status: "active",
  };

  let generateEmailConfirmation = (~user: User.t) => {
    kind: "email_confirmation",
    id: Sihl.Core.Uuid.V4.uuidv4(),
    user: user.id,
    // TODO replace with proper token generation
    token: Sihl.Core.Uuid.V4.uuidv4(),
    status: "active",
  };

  let generatePasswordReset = (~user: User.t) => {
    kind: "password_reset",
    id: Sihl.Core.Uuid.V4.uuidv4(),
    user: user.id,
    // TODO replace with proper token generation
    token: Sihl.Core.Uuid.V4.uuidv4(),
    status: "active",
  };

  let isEmailConfirmation = token => token.kind === "email_confirmation";
};

module EmailConfirmation = {
  let template = {|
Hello {givenName} {familyName},

Confirm your email {baseUrl}/{root}/confirm-email?token={token}

Best,
|};

  let make = (~token: Token.t, ~user: User.t) =>
    Sihl.Core.Email.make(
      // TODO set correct sender (read from config)
      ~sender="TODO read from config",
      ~recipient=user.email,
      ~subject="Email address confirmation",
      ~text=
        Sihl.Core.Email.render(
          template,
          [
            // TODO inject baseUrl and root
            ("baseUrl", "http://localhost:3000"),
            ("root", "users"),
            ("givenName", user.givenName),
            ("familyName", user.familyName),
            ("token", token.token),
          ],
        ),
    );
};

module PasswordReset = {
  let template = {|
Hello {givenName} {familyName},

Go to this URL to reset your password {baseUrl}/{root}/reset-password?token={token}

Best,
|};

  let make = (~token: Token.t, ~user: User.t) => {
    // TODO set correct sender (read from config)
    Sihl.Core.Email.make(
      ~sender="TODO read from config",
      ~recipient=user.email,
      ~subject="Password reset",
      ~text=
        Sihl.Core.Email.render(
          template,
          [
            // TODO inject baseUrl and root
            ("baseUrl", "http://localhost:3000"),
            ("root", "users"),
            ("givenName", user.givenName),
            ("familyName", user.familyName),
            ("token", token.token),
          ],
        ),
    );
  };
};
