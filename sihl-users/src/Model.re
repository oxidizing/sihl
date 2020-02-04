module User = {
  [@decco]
  type t = {
    username: string,
    email: string,
    password: string,
  };

  let encode = t_encode;
  let decode = t_decode;
};

module Users = {
  [@decco]
  type t = list(User.t);

  let encode = t_encode;
  let decode = t_decode;
};
