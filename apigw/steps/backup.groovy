void call(String gw, String api) {
  withCredentials([usernamePassword(
    credentialsId: 'apigwcredential',
    usernameVariable: 'APIGW_USER',
    passwordVariable: 'APIGW_PASS'
  )]) {

    def result = sh(
      script: """
        chmod +x common.sh
        ./common.sh backup_api "${api}" "${gw}" "$APIGW_USER" "$APIGW_PASS"
      """,
      returnStdout: true
    ).trim()

    // ambil hanya baris terakhir (hindari output lain ikut terbaca)
    def lastLine = result.split('\n')[-1].trim()
    def parts    = lastLine.split('\\|')

    env.BACKUP_FILE = parts[0]
    env.APP_FILE    = parts.size() > 1 ? parts[1] : ''

    echo "Backup file: ${env.BACKUP_FILE}"
    echo "App file: ${env.APP_FILE}"

    return env.BACKUP_FILE   
  }
}