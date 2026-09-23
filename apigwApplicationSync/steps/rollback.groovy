void call(String gw, String app) {

  withCredentials([usernamePassword(
    credentialsId: env.CRED_ID,
    usernameVariable: 'U',
    passwordVariable: 'P'
  )]) {

    sh """
      chmod +x common.sh
      ./common.sh rollback_app "${env.BACKUP_FILE}" "${app}" "${gw}" "$U" "$P"
    """
  }
}