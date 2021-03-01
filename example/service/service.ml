module User = Sihl_user.PostgreSql
module Token = Sihl_token.JwtPostgreSql
module PasswordResetService = Sihl_user.Password_reset.MakePostgreSql (Token)
