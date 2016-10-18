#!groovy

def call(body) {

  def config = [:]
  body.resolveStrategy = Closure.DELEGATE_FIRST
  body.delegate = config
  body()


  def a = new ultis.GetPropertyList
  a.test()

  node {
    stage 'build'
    timeout(config.timeout) {

    echo "Starting aurora build, project:$env.GERRIT_PROJECT, branch:$env.GERRIT_BRANCH refspec:$env.GERRIT_REFSPEC"
    }
  }
}

