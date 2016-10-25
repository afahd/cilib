#!groovy

def call(body) {

  def args = [:]
  body.resolveStrategy = Closure.DELEGATE_FIRST
  body.delegate = args
  body()
  
  node('gcloud-slave') {
    
    dir('andromeda') 
    {
      //git branch: 'refs/changes/80/26680/6', url: 'ssh://afahd@gerrit.plumgrid.com:29418/andromeda'
      //checkout ('FETCH_HEAD')
      
      checkout([$class: 'GitSCM', 
          userRemoteConfigs: [[url: 'ssh://afahd@gerrit.plumgrid.com:29418/andromeda',refspec:'refs/changes/80/26680/6']]
      ])
    } 
    
    withEnv(["PATH=/opt/plumgrid/google-cloud-sdk/bin/:/opt/pg/scripts:$PATH"]) 
    {
      //sh 'cd andromeda/gcloud/; mkdir -p build; cd build; cmake ..; make install;'
      echo "$args.name"
      stage 'build'
      echo "Starting aurora build, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH refspec:$GERRIT_REFSPEC"
      //sh "aurora build -p corelib -b master -t core"
      //def string_out = readFile('logs/build_id')
      //def build_id = string_out.replace("BUILD-ID=","")
      //echo "$build_id"
      
      
      
    }
     
  }
}

