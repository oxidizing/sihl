module Users = {
  [@react.component]
  let make = (~users: list(Model.User.t)) =>
    <div> <span> {React.string("hello there " ++ "foo")} </span> </div>;
};

module User = {
  [@react.component]
  let make = (~user: Model.User.t) =>
    <div> <span> {React.string("hello there " ++ "foo")} </span> </div>;
};
