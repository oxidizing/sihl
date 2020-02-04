open Belt.Result;
module User: {
  let getAll:
    Sihl.Core.Db.Connection.t =>
    Future.t(Belt.Result.t(list(Model.User.t), string));
  let get:
    Sihl.Core.Db.Connection.t =>
    Future.t(Belt.Result.t(Model.User.t, string));
} = {
  let getAll = connection => []->Belt.Result.Ok->Future.value;
  let get = connection => Belt.Result.Error("Not found")->Future.value;
};
