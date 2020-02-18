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
  };

  let make =
      (~email, ~username, ~password, ~givenName, ~familyName, ~phone, ~admin) => {
    let id = Sihl.Core.Uuid.V4.uuidv4();
    Belt.Result.Ok({
      id,
      email,
      username,
      password,
      givenName,
      familyName,
      phone,
      status: "active",
      admin,
    });
  };

  let isAdmin = user => user.admin;
};

module Token = {
  [@decco]
  type t = {
    id: string,
    user: string,
    token: string,
  };

  let generate = (~user: User.t) => {
    id: Sihl.Core.Uuid.V4.uuidv4(),
    user: user.id,
    // TODO replace with proper token generation
    token: Sihl.Core.Uuid.V4.uuidv4(),
  };
};
