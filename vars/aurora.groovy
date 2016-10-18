
def call(body) {

  def config = [:]
  body.resolveStrategy = Closure.DELEGATE_FIRST
  body.delegate = config
  body()
  
  node {
    stage 'build'
    timeout(config.timeout) {
    
    echo 'Starting aurora build, project:$env.GERRIT_PROJECT, branch:$env.GERRIT_BRANCH refspec:$env.GERRIT_REFSPEC'
    sh 'aurora build -p $GERRIT_PROJECT' -b '$GERRIT_BRANCH' -r '$GERRIT_REFSPEC' -T 'automaton'
      
    
  }
  }
}
