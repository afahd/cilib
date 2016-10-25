#!groovy

def call(body) {

  def args = [:]
  body.resolveStrategy = Closure.DELEGATE_FIRST
  body.delegate = args
  body()
  
  node('local-node') {
    git'ssh://gerrit.plumgrid.com:29418/andromeda'
    dir ('gcloud')
    {
      sh "mkdir $pwd/build;" 
    }
    echo "$args.name"
    stage 'build'
    echo "Starting aurora build, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH refspec:$GERRIT_REFSPEC"
  }
}

