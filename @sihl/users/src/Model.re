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

  let canResetPassword = token =>
    token.kind === "password_reset" && token.status === "active";

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

// TODO make email configurable
module EmailConfirmation = {
  let template = {|
Hi {givenName} {familyName},

Thanks for signing up.

Please go to this URL to confirm your email address: {baseUrl}/app/confirm-email?token={token}

Best,
Josef
|};

  let make = (~token: Token.t, ~user: User.t) =>
    Sihl.Core.Email.make(
      ~sender=
        Sihl.Core.Config.get(~default="josef@oxidizing.io", "EMAIL_SENDER"),
      ~recipient=user.email,
      ~subject="Email Address Confirmation",
      ~text=
        Sihl.Core.Email.render(
          template,
          [
            (
              "baseUrl",
              Sihl.Core.Config.get(
                ~default="http://localhost:3000",
                "BASE_URL",
              ),
            ),
            ("root", "users"),
            ("givenName", user.givenName),
            ("familyName", user.familyName),
            ("token", token.token),
          ],
        ),
    );
};

// TODO make email configurable
module PasswordReset = {
  let template = {|
Hi {givenName} {familyName},

You requested to reset your password.

Please go to this URL to reset your password: {baseUrl}/app/password-reset?token={token}

Best,
Josef
|};

  let make = (~token: Token.t, ~user: User.t) => {
    Sihl.Core.Email.make(
      ~sender=
        Sihl.Core.Config.get(~default="josef@oxidizing.io", "EMAIL_SENDER"),
      ~recipient=user.email,
      ~subject="Password Reset",
      ~text=
        Sihl.Core.Email.render(
          template,
          [
            (
              "baseUrl",
              Sihl.Core.Config.get(
                ~default="http://localhost:3000",
                "BASE_URL",
              ),
            ),
            ("root", "users"),
            ("givenName", user.givenName),
            ("familyName", user.familyName),
            ("token", token.token),
          ],
        ),
    );
  };
};
