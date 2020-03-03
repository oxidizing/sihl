module Issue = {
  [@decco]
  type t = {
    id: string,
    title: string,
    description: option(string),
    status: string,
    assignee: string,
    board: string,
  };
};
