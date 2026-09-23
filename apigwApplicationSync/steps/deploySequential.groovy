void call() {
  prepareScripts()
  def gateways   = config.gatewayUrls
  def masterGateway = env.MASTER_APIGATEWAY_URL
  def esList     = config.esUrls
  def applicationName = env.APPLICATION_NAME
  def choice = params['app']
  echo "Selected: ${choice}"

  def results = [:]

  for (int i = 0; i < gateways.size(); i++) {
    def gw    = gateways[i].trim()
    // def esUrl = esList[i].trim()

    if (gw == masterGateway) {
        echo "Skipping master gateway...Continue"
        continue
    }

    stage("GW-${i+1} (${gw})") {
      def backupFile = ''

      try {
        precheck(gw)
        backupFile = backup(gw, applicationName)   
        importApp(applicationName, gw, masterGateway)             
        postcheck(applicationName, gw, masterGateway)             
        // testApp(gw, esUrl)

        results[gw] = 'SUCCESS'
      } catch (err) {
        echo "FAILED on ${gw}: ${err.message}"
        results[gw] = 'FAILED'
        if (backupFile) {
          rollback(gw, applicationName)    
        }    
        error("STOP DEPLOY — failure on ${gw}")
      }
    }
  }

  env.DEPLOY_RESULTS = results.collect { k, v -> "${k}=${v}" }.join(',')
}