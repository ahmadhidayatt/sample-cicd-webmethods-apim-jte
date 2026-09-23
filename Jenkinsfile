
node {
    loadProperties()

    checkout([
        $class: 'GitSCM',
        branches: [[name: "*/${env.REPO_BRANCH}"]],
        userRemoteConfigs: [[
            url: env.REPO_URL,
            credentialsId: env.REPO_CRED_ID
        ]]
    ])
    deploy()
    summary()
}
