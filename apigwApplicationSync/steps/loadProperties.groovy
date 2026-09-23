void call() {
  env.REPO_URL       = config.repoUrl
  env.REPO_BRANCH    = config.repoBranch
  env.REPO_CRED_ID   = config.repoCredId
  env.APPLICATION_NAME = config.applicationName
  env.APIGATEWAY_URLS    = config.gatewayUrls
  env.APIGATEWAY_ES_URLS = config.esUrls
  env.MASTER_APIGATEWAY_URL = config.masterGatewayUrl
  env.CRED_ID = config.credentialsId
}