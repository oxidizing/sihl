module NodeBuffer = {
  [@bs.val] external buffer: Node_buffer.t = "Buffer";
  [@bs.send] external toString: (Node_buffer.t, string) => string = "toString";
  [@bs.val]
  external fromString: (string, string) => Node_buffer.t = "Buffer.from";
};

let encode = str => {
  let buffer = NodeBuffer.fromString(str, "utf8");
  NodeBuffer.toString(buffer, "base64");
};

let decode = str => {
  NodeBuffer.toString(NodeBuffer.fromString(str, "base64"), "utf8");
};
