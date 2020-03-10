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

module Msg = {
  [@decco]
  type t = {msg: string};
};

let handleResponse = (response, resolve, reject) => {
  module Async = Sihl.Core.Async;
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
