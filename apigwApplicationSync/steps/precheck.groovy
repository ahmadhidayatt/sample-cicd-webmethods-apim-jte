void call(String gw) {

  withCredentials([usernamePassword(
    credentialsId: env.CRED_ID,
    usernameVariable: 'APIGW_USER',
    passwordVariable: 'APIGW_PASS'
  )]) {

    sh """
      chmod +x common.sh
      ./common.sh validate_gateway_up "${gw}" "$APIGW_USER" "$APIGW_PASS"
    """
  }
}