void call(String gw, String esUrl) {

  withCredentials([usernamePassword(
    credentialsId: 'apigwcredential',
    usernameVariable: 'U',
    passwordVariable: 'P'
  )]) {

    sh """
      rm -rf test-results
      mkdir -p test-results

      docker run --rm \
        -v \$PWD:/etc/newman \
        -w /etc/newman \
        postman/newman:latest \
        run apigw-pipeline/tests/collection.json \
        -e apigw-pipeline/tests/environment.json \
        --env-var username=$U \
        --env-var password=$P \
        --env-var httpInvokeUrl=${gw} \
        --env-var esUrl=${esUrl} \
        --reporters cli,junit \
        --reporter-junit-export apigw-pipeline/test-results/result.xml
    """
  }
}