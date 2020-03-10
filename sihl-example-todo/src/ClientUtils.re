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

module Msg = {
  [@decco]
  type t = {msg: string};
};

let handleResponse = (response, resolve, reject) => {
  let%Async response = response;
  let%Async json = Fetch.Response.json(response);
  if (Fetch.Response.status(response) !== 200) {
    json
    ->Msg.t_decode
    ->Belt.Result.getWithDefault(
        Msg.{msg: "Error response url=" ++ Fetch.Response.url(response)},
      )
    ->((Msg.{msg}) => reject(msg));
  } else {
    resolve(json);
  };
};
