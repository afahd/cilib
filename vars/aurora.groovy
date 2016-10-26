#!groovy

def call(body) {

  def args = [:]
  body.resolveStrategy = Closure.DELEGATE_FIRST
  body.delegate = args
  body()
  
  node('gcloud-slave') {
    deleteDir()
    stage 'clone'
    dir('andromeda') 
    {
      git branch: 'master', url: 'ssh://afahd@gerrit.plumgrid.com:29418/andromeda'
    } 
    
    withEnv(["PATH=$WORKSPACE/andromeda/gcloud/build/:/opt/pg/scripts:$PATH"]) 
    {
      echo "$PATH"
      sh 'cd andromeda/gcloud/; mkdir -p build; cd build; cmake ..;'
      echo "$args.name"
      stage 'build'
      echo "Starting aurora build, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH refspec:$GERRIT_REFSPEC"
      sh "aurora build -p corelib -b master -t $BUILD_TAG"
      def string_out = readFile('logs/build_id')
      def build_id = string_out.replace("BUILD-ID=","")
      stage 'tests'
      sh "aurora test -p corelib -b master -t $args.test_tag -n $args.num_instances -i $args.iterations -l $build_id"
    }
    
    archiveArtifacts 'logs/'
     
  }
}

