module Issue = {
  [@decco]
  type t = {
    id: string,
    title: string,
    description: option(string),
    board: string,
    assignee: option(string),
    status: string,
  };

  let make = (~title, ~description, ~board) => {
    id: Sihl.Core.Uuid.V4.uuidv4(),
    title,
    description,
    board,
    assignee: None,
    status: "todo",
  };
};

module Board = {
  [@decco]
  type t = {
    id: string,
    title: string,
    owner: string,
    status: string,
  };

  let make = (~title, ~owner) => {
    id: Sihl.Core.Uuid.V4.uuidv4(),
    title,
    owner,
    status: "active",
  };
};
