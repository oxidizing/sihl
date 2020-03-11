module Async = Sihl.Core.Async;

module Http = {
  module Msg = {
    [@decco]
    type t = {msg: string};
  };
};

let decodeRespone = (response, decode) => {
  Async.catchAsync(
    {
      let%Async json = Fetch.Response.json(response);
      Async.async(
        switch (decode(json)) {
        | Belt.Result.Ok(result) => Belt.Result.Ok(result)
        | Belt.Result.Error(error) =>
          Js.log(Sihl.Core.Error.Decco.stringify(error));
          Belt.Result.Error(
            "Invalid response retrieved url="
            ++ Fetch.Response.url(response)
            ++ " "
            ++ Sihl.Core.Error.Decco.stringify(error),
          );
        },
      );
    },
    _ => {
      Js.log(
        "Failed to parse response from url=" ++ Fetch.Response.url(response),
      );
      Async.async(
        Belt.Result.Error(
          "Failed request status="
          ++ string_of_int(Fetch.Response.status(response)),
        ),
      );
    },
  );
};

let decodeResult = (~decode, response) => {
  let%Async response = response;
  if (Fetch.Response.status(response) === 200) {
    decodeRespone(response, decode);
  } else {
    let%Async result = decodeRespone(response, Http.Msg.t_decode);
    Async.async(
      switch (result) {
      | Belt.Result.Ok(Http.Msg.{msg}) => Belt.Result.Error(msg)
      | Belt.Result.Error(_) as error => error
      },
    );
  };
};

let toResult = response => {
  let%Async response = response;
  if (Fetch.Response.status(response) === 200) {
    Async.async(Belt.Result.Ok());
  } else {
    let%Async result = decodeRespone(response, Http.Msg.t_decode);
    Async.async(
      switch (result) {
      | Belt.Result.Ok(Http.Msg.{msg}) => Belt.Result.Error(msg)
      | Belt.Result.Error(_) as error => error
      },
    );
  };
};

module Board = {
  module GetAll = {
    [@decco]
    type t = list(Model.Board.t);

    let f = () => {
      let%Async user = ClientUtils.User.get();

      Fetch.fetchWithInit(
        ClientConfig.baseUrl() ++ "/issues/users/" ++ user.id ++ "/boards/",
        Fetch.RequestInit.make(
          ~method_=Get,
          ~headers=
            Fetch.HeadersInit.make({
              "authorization": "Bearer " ++ ClientUtils.Token.get(),
            }),
          (),
        ),
      )
      |> decodeResult(~decode=t_decode);
    };
  };

  module Add = {
    let f = (~title) => {
      let body = {j|{"title": "$(title)"}|j};
      Fetch.fetchWithInit(
        ClientConfig.baseUrl() ++ "/issues/boards/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~body=Fetch.BodyInit.make(body),
          ~headers=
            Fetch.HeadersInit.make({
              "authorization": "Bearer " ++ ClientUtils.Token.get(),
            }),
          (),
        ),
      )
      |> toResult;
    };
  };

  module Issues = {
    [@decco]
    type t = list(Model.Issue.t);

    let f = (~boardId) => {
      Fetch.fetchWithInit(
        ClientConfig.baseUrl() ++ "/issues/boards/" ++ boardId ++ "/issues/",
        Fetch.RequestInit.make(
          ~method_=Get,
          ~headers=
            Fetch.HeadersInit.make({
              "authorization": "Bearer " ++ ClientUtils.Token.get(),
            }),
          (),
        ),
      )
      |> decodeResult(~decode=t_decode);
    };
  };
};

module Issue = {
  module Complete = {
    let f = (~issueId) => {
      Fetch.fetchWithInit(
        ClientConfig.baseUrl() ++ "/issues/issues/" ++ issueId ++ "/complete/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~headers=
            Fetch.HeadersInit.make({
              "authorization": ClientUtils.Token.get(),
            }),
          (),
        ),
      )
      |> toResult;
    };
  };

  module Add = {
    let f = (~boardId, ~title, ~description) => {
      let description =
        description
        ->Belt.Option.map(d => "\"" ++ d ++ "\"")
        ->Belt.Option.getWithDefault("null");
      let body = {j|
       {
         "board": "$(boardId)",
         "title": "$(title)",
         "description": $(description)
       }
       |j};
      Fetch.fetchWithInit(
        ClientConfig.baseUrl() ++ "/issues/issues/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~body=Fetch.BodyInit.make(body),
          ~headers=
            Fetch.HeadersInit.make({
              "authorization": ClientUtils.Token.get(),
            }),
          (),
        ),
      )
      |> toResult;
    };
  };
};

module User = {
  module Login = {
    [@decco]
    type t = {token: string};

    let f = (~email, ~password) => {
      Fetch.fetch(
        ClientConfig.baseUrl()
        ++ "/users/login?email="
        ++ email
        ++ "&password="
        ++ password,
      )
      |> decodeResult(~decode=t_decode);
    };
  };

  module Register = {
    [@decco]
    let f = (~username, ~givenName, ~familyName, ~email, ~password) => {
      let body = {j|
       {
         "email": "$(email)",
         "username": "$(username)",
         "password": "$(password)",
         "givenName": "$(givenName)",
         "familyName": "$(familyName)"
       }
       |j};

      Fetch.fetchWithInit(
        ClientConfig.baseUrl() ++ "/users/register/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~body=Fetch.BodyInit.make(body),
          (),
        ),
      )
      |> toResult;
    };
  };
};
