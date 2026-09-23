void call() {
  prepareScripts()
  def gateways   = config.gatewayUrls
  def esList     = config.esUrls
  def apiProject = config.apiProject

  def results = [:]

  for (int i = 0; i < gateways.size(); i++) {
    def gw    = gateways[i].trim()
    def esUrl = esList[i].trim()

    def backupFile = ''

    try {
      stage("Precheck (${gw})") {
        precheck(gw)
      }
      
      stage("Backup (${gw})") {
        backupFile = backup(gw, apiProject)   
      }
      
      stage("Import API (${gw})") {
        importApi(apiProject, gw)             
      }
      
      stage("Postcheck (${gw})") {
        postcheck(apiProject, gw)             
      }
      
      stage("Test API (${gw})") {
        testApi(gw, esUrl)
      }

      results[gw] = 'SUCCESS'
    } catch (err) {
      echo "FAILED on ${gw}: ${err.message}"
      results[gw] = 'FAILED'

      stage("Rollback (${gw})") {
        rollback(backupFile, gw)             
      }
      error("STOP DEPLOY - failure on ${gw}")
    }
  }

  env.DEPLOY_RESULTS = results.collect { k, v -> "${k}=${v}" }.join(',')
}