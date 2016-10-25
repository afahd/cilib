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
      //def value = "$pwd/build/"
      sh "ls; mkdir -p build; cd build; cmake..; make install;"
      
    }
    echo "$args.name"
    stage 'build'
    echo "Starting aurora build, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH refspec:$GERRIT_REFSPEC"
  }
}

