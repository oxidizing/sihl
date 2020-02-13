module User = {
  [@decco]
  type t = {
    id: string,
    email: string,
    username: string,
    password: string,
    givenName: string,
    familyName: string,
    phone: option(string),
  };

  let make = (~email, ~username, ~password, ~givenName, ~familyName, ~phone) => {
    let id = Sihl.Core.Uuid.V4.uuidv4();
    Belt.Result.Ok({
      id,
      email,
      username,
      password,
      givenName,
      familyName,
      phone,
    });
  };
};

module Token = {
  [@decco]
  type t = {
    id: string,
    userId: string,
    token: string,
  };

  let generate = (~user: User.t) => {
    id: Sihl.Core.Uuid.V4.uuidv4(),
    userId: user.id,
    // TODO replace with proper token generation
    token: Sihl.Core.Uuid.V4.uuidv4(),
  };

  let fromHeader = header =>
    Js.String.split(header, " ")->Belt.Array.reverse->Belt.Array.get(0);
};
