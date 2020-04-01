type t('database, 'endpoint, 'cliCommand) = {
  name: string,
  namespace: string,
  routes: 'database => list('endpoint),
  migration: SihlCoreDb.Migration.t,
  commands: list('cliCommand),
  configurationSchema: SihlCoreConfig.Schema.t,
};
