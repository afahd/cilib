#!groovy

def call(body) {

  def args = [:]
  body.resolveStrategy = Closure.DELEGATE_FIRST
  body.delegate = args
  body()
  
  node('gcloud-slave') {
    
    dir('andromeda') 
    {
      git branch: 'master', url: 'ssh://alir@gerrit.plumgrid.com:29418/andromeda'
    }  
    sh 'cd andromeda/gcloud/; mkdir -p build; cd build; cmake ..; make install;'
    sh 'aurora --help'
   
    echo "$args.name"
    stage 'build'
    echo "Starting aurora build, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH refspec:$GERRIT_REFSPEC"
  }
}

