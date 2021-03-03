module Migration = Sihl.Database.Migration.PostgreSql
module User = Sihl_user.PostgreSql
module Token = Sihl_token.JwtPostgreSql
module PasswordResetService = Sihl_user.Password_reset.MakePostgreSql (Token)
module EmailTemplate = Sihl_email.Template.PostgreSql
module MarketingEmail = Sihl_email.SendGrid
module TransactionalEmail = Sihl_email.Smtp
module Queue = Sihl_queue.PostgreSql
