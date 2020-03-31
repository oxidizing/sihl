let catchAsResult = (f, error) =>
  switch (f()) {
  | value => Ok(value)
  | exception _ => Error(error)
  };

let optionAsResult = (error, optn) => {
  switch (optn) {
  | Some(value) => Ok(value)
  | None => Error(error)
  };
};

exception ServerException(string);

let failIfError = result => {
  switch (result) {
  | Ok(ok) => ok
  | Error(msg) => raise(ServerException(msg))
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
    | Ok(_) as ok => ok
    | Error(error) => Error(stringify(error))
    };
  };

  let stringifyDecoder = (decoder, json) => {
    switch (decoder(json)) {
    | Ok(_) as ok => ok
    | Error(error) => Error(stringify(error))
    };
  };
};
