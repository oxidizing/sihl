module Async = SihlCore_Async;

let devInbox: Pervasives.ref(option(SihlCore_Email_Core.t)) = ref(None);

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
    [@bs.send] external send: (t, Email.t) => Async.t(unit) = "sendMail";
    [@bs.send] external verify: t => Async.t(unit) = "verify";

    let make = (~host, ~port, ~secure, ~auth, ~pool, ()) => {
      Config.make(~host, ~port, ~secure, ~auth, ~pool, ()) |> create;
    };
  };
};

let send = (email: SihlCore_Email_Core.t) =>
  switch (SihlCore_Config.get(~default="console", "EMAIL_BACKEND")) {
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
        ~host=SihlCore_Config.get("SMTP_HOST"),
        ~port=SihlCore_Config.getInt("SMTP_PORT"),
        ~auth={
          "user": SihlCore_Config.get("SMTP_AUTH_USERNAME"),
          "pass": SihlCore_Config.get("SMTP_AUTH_PASSWORD"),
        },
        ~secure=SihlCore_Config.getBool("SMTP_SECURE"),
        ~pool=SihlCore_Config.getBool(~default=false, "SMTP_POOL"),
        (),
      );
    Nodemailer.Transport.send(transport, email)
    ->Async.mapAsync(_ =>
        SihlCore_Log.info(
          "email sent using smtp backend recipient=" ++ recipient,
          (),
        )
      );
  | "console" =>
    Async.async @@ SihlCore_Log.info(SihlCore_Email_Core.toString(email), ())
  | _ =>
    devInbox := Some(email);
    Async.async();
  };
