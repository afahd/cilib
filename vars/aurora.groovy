#!groovy

import utils.GetPropertyList

def call(body) {

  def config = [:]
  body.resolveStrategy = Closure.DELEGATE_FIRST
  body.delegate = config
  body()


  properties(GetPropertyList(config))

  node {
    stage 'build'
    timeout(config.timeout) {

    echo "Starting aurora build, project:$env.GERRIT_PROJECT, branch:$env.GERRIT_BRANCH refspec:$env.GERRIT_REFSPEC"
    }
  }
}

