type t = {
  token: string,
  userId: string,
};

exception SessionFetchException;

let store = (~token, ~userId) => {
  open Dom.Storage;
  setItem("/users/token", token, localStorage);
  setItem("/users/userId", userId, localStorage);
};

let get = () => {
  Dom.Storage.(
    switch (
      getItem("/users/token", localStorage),
      getItem("/users/userId", localStorage),
    ) {
    | (Some(token), Some(userId)) => {token, userId}
    | _ =>
      ReasonReactRouter.push("/app/login");
      let _ = removeItem("/users/token");
      let _ = removeItem("/users/userId");
      raise(SessionFetchException);
    }
  );
};

let end_ = () => {
  open Dom.Storage;
  removeItem("/users/token", localStorage);
  removeItem("/users/userId", localStorage);
};

let has = () => {
  Dom.Storage.(
    switch (
      getItem("/users/token", localStorage),
      getItem("/users/userId", localStorage),
    ) {
    | (Some(_), Some(_)) => true
    | _ => false
    }
  );
};
