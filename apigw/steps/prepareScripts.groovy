void call() {
  String  commonLib = resource('gateway_lib.sh')

  echo 'Preparing shell scripts from JTE library...'

  writeFile file: 'common.lib', text: commonLib
  writeFile file: 'common.sh', text: commonLib

  sh 'pwd'
  echo 'DEBUG LIBRARY RESOURCE'
  sh 'ls -R $JENKINS_HOME/workspace/@libs || true'
}
