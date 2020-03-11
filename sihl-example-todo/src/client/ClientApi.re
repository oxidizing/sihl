module Async = Sihl.Core.Async;

module Board = {
  module GetAll = {
    [@decco]
    type t = list(Model.Board.t);

    let f = () => {
      let%Async user = ClientUtils.User.get();
      let%Async response =
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
        );
      let%Async json = Fetch.Response.json(response);
      Async.async(
        switch (t_decode(json)) {
        | Belt.Result.Ok(_) as result => result
        | Belt.Result.Error(msg) =>
          Belt.Result.Error(Sihl.Core.Error.Decco.stringify(msg))
        },
      );
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
      );
    };
  };

  module Issues = {
    [@decco]
    type t = list(Model.Issue.t);

    let f = (~boardId) => {
      let%Async response =
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
        );
      let%Async json = Fetch.Response.json(response);
      Async.async(
        switch (t_decode(json)) {
        | Belt.Result.Ok(_) as result => result
        | Belt.Result.Error(msg) =>
          Belt.Result.Error(Sihl.Core.Error.Decco.stringify(msg))
        },
      );
    };
  };
};

module Issue = {
  module Complete = {
    let f = (~issueId) => {
      let%Async _ =
        Fetch.fetchWithInit(
          ClientConfig.baseUrl()
          ++ "/issues/issues/"
          ++ issueId
          ++ "/complete/",
          Fetch.RequestInit.make(
            ~method_=Post,
            ~headers=
              Fetch.HeadersInit.make({
                "authorization": ClientUtils.Token.get(),
              }),
            (),
          ),
        );
      // TODO return based on status code
      Async.async(Belt.Result.Ok());
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

      let%Async _ =
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
        );
      // TODO return added issue
      Async.async(Belt.Result.Ok());
    };
  };
};
