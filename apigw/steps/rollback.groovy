void call(String gw) {

  withCredentials([usernamePassword(
    credentialsId: 'apigwcredential',
    usernameVariable: 'U',
    passwordVariable: 'P'
  )]) {

    sh """
      chmod +x common.sh
      ./common.sh rollback_api "${env.BACKUP_FILE}" "${gw}" "$U" "$P"
    """
  }
}