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

exception ServerException(string);

let failIfError = result => {
  switch (result) {
  | Belt.Result.Ok(ok) => ok
  | Belt.Result.Error(error) => raise(ServerException(error))
  };
};

module Decco = {
  let stringify = ({Decco.path, Decco.message, Decco.value}) =>
    "Failed to decode at location="
    ++ path
    ++ ", message="
    ++ message
    ++ ", json="
    ++ Js.Json.stringify(value);

  let stringifyResult = res => {
    switch (res) {
    | Belt.Result.Ok(_) as ok => ok
    | Belt.Result.Error(error) => Belt.Result.Error(stringify(error))
    };
  };
  let stringifyDecoder = (decoder, json) => {
    switch (decoder(json)) {
    | Belt.Result.Ok(_) as ok => ok
    | Belt.Result.Error(error) => Belt.Result.Error(stringify(error))
    };
  };
};
