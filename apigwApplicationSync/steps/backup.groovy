void call(String gw, String app) {
  withCredentials([usernamePassword(
    credentialsId: env.CRED_ID,
    usernameVariable: 'APIGW_USER',
    passwordVariable: 'APIGW_PASS'
  )]) {

    def result = sh(
      script: """
        chmod +x common.sh
        ./common.sh backup_app "${app}" "${gw}" "$APIGW_USER" "$APIGW_PASS"
      """,
      returnStdout: true
    ).trim()

    env.BACKUP_FILE = result
    echo "Backup file: ${env.BACKUP_FILE}"

    return env.BACKUP_FILE   
  }
}