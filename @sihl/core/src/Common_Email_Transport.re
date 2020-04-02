module Async = Common_Async;

let devInbox: Pervasives.ref(option(Common_Email_Core.t)) = ref(None);

let getLastEmail = () => devInbox^;

module Nodemailer = {
  module Email = {
    [@bs.deriving abstract]
    type t = {
      from: string,
      [@bs.as "to"]
      to_: string,
      [@bs.optional]
      bcc: string,
      [@bs.optional]
      subject: string,
      [@bs.optional]
      text: string,
      [@bs.optional]
      html: string,
    };

    let make = t;
  };

  module Config = {
    type auth = {
      .
      "user": string,
      "pass": string,
    };

    [@bs.deriving abstract]
    type t = {
      host: string,
      port: int,
      secure: bool,
      pool: bool,
      [@bs.optional]
      auth,
    };

    let make = t;
  };

  module Transport = {
    type t;
    [@bs.module "nodemailer"]
    external create: Config.t => t = "createTransport";
    [@bs.send] external send: (t, Email.t) => Js.Promise.t(unit) = "sendMail";
    [@bs.send] external verify: t => Js.Promise.t(unit) = "verify";

    let make = (~host, ~port, ~secure, ~auth, ~pool, ()) => {
      Config.make(~host, ~port, ~secure, ~auth, ~pool, ()) |> create;
    };
  };
};

let send = (email: Common_Email_Core.t) =>
  switch (Common_Config.get(~default="console", "EMAIL_BACKEND")) {
  | "smtp" =>
    let recipient = email.recipient;
    let email =
      Nodemailer.Email.make(
        ~from=email.sender,
        ~to_=email.recipient,
        ~subject=email.subject,
        ~text=email.text,
        (),
      );
    let transport =
      Nodemailer.Transport.make(
        ~host=Common_Config.get("SMTP_HOST"),
        ~port=Common_Config.getInt("SMTP_PORT"),
        ~auth={
          "user": Common_Config.get("SMTP_AUTH_USERNAME"),
          "pass": Common_Config.get("SMTP_AUTH_PASSWORD"),
        },
        ~secure=Common_Config.getBool("SMTP_SECURE"),
        ~pool=Common_Config.getBool(~default=false, "SMTP_POOL"),
        (),
      );
    Nodemailer.Transport.send(transport, email)
    ->Async.mapAsync(_ =>
        Common_Log.info(
          "email sent using smtp backend recipient=" ++ recipient,
          (),
        )
      );
  | "console" =>
    Async.async @@ Common_Log.info(Common_Email_Core.toString(email), ())
  | _ =>
    devInbox := Some(email);
    Async.async();
  };
