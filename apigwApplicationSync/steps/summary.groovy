void call() {
  echo "===== DEPLOYMENT SUMMARY ====="

  def resultsStr = env.DEPLOY_RESULTS ?: ''
  if (!resultsStr) {
    echo "No results found."
    return
  }

  resultsStr.split(',').each { entry ->
    def parts = entry.split('=')
    def gw    = parts[0]
    def status = parts.size() > 1 ? parts[1] : 'UNKNOWN'
    echo "${gw} → ${status}"
  }
}