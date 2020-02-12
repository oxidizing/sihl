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
    created: string,
    updated: string,
  };

  let encode = t_encode;
  let decode = t_decode;

  let doesMatchPassword = (~user, ~plainText) =>
    Belt.Result.Error("Invalid password provided");
};

module Token = {
  type t = {
    userId: string,
    token: string,
  };
  let generate = (~user: User.t) => {userId: user.id, token: "TODO"};
};
