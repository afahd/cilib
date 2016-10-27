#!groovy

def call(body) {

  def args = [:]
  body.resolveStrategy = Closure.DELEGATE_FIRST
  body.delegate = args
  body()
  
  def iter = 1
  
  if (args.trigger_path != null)
  {
    def a = new utils.GetPropertyList()
    properties(a.GetPropertyList(args))
  }
  
  if (args.iterations != null)
  {
    iter = args.iterations 
  }
  
  node('gcloud-slave') {
      
      stage 'clone'
      dir('andromeda') 
      {
        //git branch: 'master', url: 'ssh://afahd@gerrit.plumgrid.com:29418/andromeda'
      } 

      withEnv(["PATH=/opt/plumgrid/google-cloud-sdk/bin/:$WORKSPACE/andromeda/gcloud/build:/opt/pg/scripts:$PATH"]) 
      {
       // sh 'cd andromeda/gcloud/; mkdir -p build; cd build; cmake ..;'

        stage 'build'
        echo "Starting aurora build, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH refspec:$GERRIT_REFSPEC"
       // sh "aurora build -p $GERRIT_PROJECT -b $GERRIT_BRANCH -t $JOB_BASE_NAME+$BUILD_NUMBER -r $GERRIT_REFSPEC"
        //def string_out = readFile('logs/build_id')
        //def build_id = string_out.replace("BUILD-ID=","")
        def build_id = "123"
        stage 'test'
        
        String testing = "aurora test -p $GERRIT_PROJECT -b $GERRIT_BRANCH -t $args.ctest_tag -n $args.num_instances -i $iter -A $args.test_args -l $build_id"
        echo "$testing"
        sh "$testing"
      }

      archiveArtifacts "$args.archive"
      step([$class: 'WsCleanup'])
     
  }
}

