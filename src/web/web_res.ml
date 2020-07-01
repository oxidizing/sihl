type content_type = Html

type t = {
  content_type : content_type;
  redirect : string option;
  content : string option;
}

let html = { content_type = Html; redirect = None; content = None }

let redirect path =
  { content_type = Html; redirect = Some path; content = None }

let content str req = { req with content = Some str }
