let wrapFormValue = event => {
  let value = ReactEvent.Form.target(event)##value;
  value === "" ? None : Some(value);
};

module Msg = {
  [@decco]
  type t = {msg: string};
};

let handleResponse = (response, res, rej) => {
  module Async = Sihl.Core.Async;

  let%Async response = response;
  if (Fetch.Response.status(response) !== 200) {
    let%Async json = Fetch.Response.json(response);
    json
    ->Msg.t_decode
    ->Belt.Result.getWithDefault(
        Msg.{msg: "Error response url=" ++ Fetch.Response.url(response)},
      )
    ->((Msg.{msg}) => rej(msg))
    ->Async.async;
  } else {
    Async.async(res());
  };
};
