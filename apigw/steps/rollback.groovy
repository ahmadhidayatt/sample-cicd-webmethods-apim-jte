void call(String backupFile, String gw) {

  withCredentials([usernamePassword(
    credentialsId: 'apigwcredential',
    usernameVariable: 'U',
    passwordVariable: 'P'
  )]) {

    sh """
      chmod +x common.sh
      ./common.sh rollback_api "${backupFile}" "${gw}" "$U" "$P"
    """
  }
}
