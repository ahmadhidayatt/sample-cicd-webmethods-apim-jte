void call(String api, String gw) {

  withCredentials([usernamePassword(
    credentialsId: 'apigwcredential',
    usernameVariable: 'U',
    passwordVariable: 'P'
  )]) {

    sh """
      chmod +x common.sh

      ./common.sh validate_api_exists "${api}" "${gw}" "$U" "$P"
      ./common.sh validate_application "${api}" "${gw}" "$U" "$P"
    """
  }
}