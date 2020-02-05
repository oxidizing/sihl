type t = [
  | `ClientError(string)
  | `NotFoundError(string)
  | `ForbiddenError(string)
  | `AuthenticationError(string)
  | `AuthorizationError(string)
  | `ServerError(string)
];

let message = error => {
  switch (error) {
  | `ClientError(value) => value
  | `NotFoundError(value) => value
  | `ForbiddenError(value) => value
  | `AuthenticationError(value) => value
  | `AuthorizationError(value) => value
  | `ServerError(value) => value
  };
};

let catchAsResult = (f, error) =>
  switch (f()) {
  | value => Belt.Result.Ok(value)
  | exception _ => Belt.Result.Error(error)
  };

let optionAsResult = (error, optn) => {
  switch (optn) {
  | Some(value) => Belt.Result.Ok(value)
  | None => Belt.Result.Error(error)
  };
};
