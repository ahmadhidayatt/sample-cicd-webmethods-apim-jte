void call(String api, String gw) {
  withCredentials([usernamePassword(
    credentialsId: 'apigwcredential',
    usernameVariable: 'U',
    passwordVariable: 'P'
  )]) {
    sh """
      chmod +x common.sh
      ./common.sh import_api "${api}" "${gw}" "$U" "$P"
    """
  }
}
