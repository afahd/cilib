def call(body) {
    // evaluate the body block, and collect configuration into the object
    def config = [:]
    body.resolveStrategy = Closure.DELEGATE_FIRST
    body.delegate = config
    body()
    node('master') {
      git 'ssh://afahd@192.168.10.77:29418/phoenix.git'
      load 'jenkins/jenkinsfiles/lint'
      }
    }
