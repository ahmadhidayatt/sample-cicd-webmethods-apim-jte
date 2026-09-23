void call() {
  env.REPO_URL       = config.repoUrl
  env.REPO_BRANCH    = config.repoBranch
  env.REPO_CRED_ID   = config.repoCredId
  
  def props = readProperties file: 'apigw-pipeline/jenkins/jenkins.properties'
  env.API_PROJECT        = props['api_project']
  env.APIGATEWAY_URLS    = props['apigateway_urls']
  env.APIGATEWAY_ES_URLS = props['apigateway_es_urls']
}