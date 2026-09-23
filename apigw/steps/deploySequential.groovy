void call() {
  prepareScripts()
  def gateways   = config.gatewayUrls
  def esList     = config.esUrls
  def apiProject = config.apiProject

  def results = [:]

  for (int i = 0; i < gateways.size(); i++) {
    def gw    = gateways[i].trim()
    def esUrl = esList[i].trim()

    stage("GW-${i+1} (${gw})") {
      def backupFile = ''

      try {
        precheck(gw)
        backupFile = backup(gw, apiProject)   
        importApi(apiProject, gw)             
        postcheck(apiProject, gw)             
        testApi(gw, esUrl)

        results[gw] = 'SUCCESS'
      } catch (err) {
        echo "FAILED on ${gw}: ${err.message}"
        results[gw] = 'FAILED'

        rollback(backupFile, gw)             
        error("STOP DEPLOY — failure on ${gw}")
      }
    }
  }

  env.DEPLOY_RESULTS = results.collect { k, v -> "${k}=${v}" }.join(',')
}