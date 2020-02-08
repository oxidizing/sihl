let (>>) = Tablecloth.(>>);

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
  let decode = t_decode >> Sihl.Core.Error.decodeToServerError;
};

module Users = {
  [@decco]
  type t = list(User.t);

  let encode = t_encode;
  let decode = t_decode;
};
