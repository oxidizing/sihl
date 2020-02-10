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

let decodeToServerError = res =>
  switch (res) {
  | Belt.Result.Ok(_) as result => result
  | Belt.Result.Error({Decco.path, Decco.message, Decco.value}) =>
    Belt.Result.Error(
      `ServerError(
        "Failed to decode at "
        ++ path
        ++ ", "
        ++ message
        ++ ", got "
        ++ Js.Json.stringify(value),
      ),
    )
  };

let flatten = errors =>
  Belt.List.reduce(errors, Belt.Result.Ok(), (acc, err) =>
    Belt.Result.flatMap(acc, _ => err)
  );
