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
