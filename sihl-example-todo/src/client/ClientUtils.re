module Async = Sihl.Core.Async;

let wrapFormValue = event => {
  let value = ReactEvent.Form.target(event)##value;
  value === "" ? None : Some(value);
};

module Token = {
  let set = token =>
    Dom.Storage.(setItem("/users/token", token, localStorage));
  let get = () =>
    switch (Dom.Storage.(getItem("/users/token", localStorage))) {
    | Some(token) => token
    | None =>
      ReasonReactRouter.push("/app/login");
      "";
    };
  let delete = () => Dom.Storage.(removeItem("/users/token", localStorage));
};

exception FetchException(string);

module User = {
  let currentUser: Pervasives.ref(option(SihlUsers.Model.User.t)) =
    ref(None);
  let isLoggedIn = () => Belt.Option.isSome(currentUser^);
  let get = () => {
    switch (currentUser^) {
    | Some(user) => Async.async(user)
    | None =>
      let token = Token.get();
      let%Async response =
        Fetch.fetchWithInit(
          ClientConfig.baseUrl() ++ "/users/users/me/",
          Fetch.RequestInit.make(
            ~method_=Get,
            ~headers=
              Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}),
            (),
          ),
        );
      let%Async json = Fetch.Response.json(response);
      switch (SihlUsers.Model.User.t_decode(json)) {
      | Belt.Result.Ok(user) =>
        currentUser := Some(user);
        Async.async(user);
      | Belt.Result.Error(msg) =>
        Js.log(Sihl.Core.Error.Decco.stringify(msg));
        raise(FetchException(Sihl.Core.Error.Decco.stringify(msg)));
      };
    };
  };
};
