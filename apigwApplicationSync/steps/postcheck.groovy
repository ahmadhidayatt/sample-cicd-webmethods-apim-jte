void call(String app, String gw, String masterGw) {

  withCredentials([usernamePassword(
    credentialsId: env.CRED_ID,
    usernameVariable: 'U',
    passwordVariable: 'P'
  )]) {

    sh """
      chmod +x common.sh
      ./common.sh validate_application "${app}" "${gw}" "${masterGw}" "$U" "$P"
    """
  }
}