#!groovy

def call(body) {

  def args = [:]
  body.resolveStrategy = Closure.DELEGATE_FIRST
  body.delegate = args
  body()
  
  // Default Values
  def iter = 1
  def archive = "logs/"
  
  // Check if trigger path modified 
  if (args.trigger_path != null)
  {
    def a = new utils.GetPropertyList()
    properties(a.GetPropertyList(args))
  }
  
  // Check if number of iterations given
  if (args.iterations != null)
  {
    iter = args.iterations 
  }
  
  // Check if artifacts to archive given
  if (args.archive != null)
  {
    archive = args.archive 
  }
  
  // Check if no empty variable exists 
  if (GERRIT_REFSPEC == null)
  {
   error 'No GERRIT_REFSPEC found'
  }
  if (GERRIT_BRANCH == null)
  {
   error 'No GERRIT_BRANCH found'
  }
  if (GERRIT_PROJECT == null)
  {
   error 'No GERRIT_PROJECT found'
  }
  
  node('gcloud-slave')
  {
      //step([$class: 'WsCleanup'])
      stage 'Clone'
      
      dir('andromeda') 
      {
        //git branch: 'master', url: 'ssh://afahd@gerrit.plumgrid.com:29418/andromeda'
      } 

      withEnv(["PATH=/opt/plumgrid/google-cloud-sdk/bin/:$WORKSPACE/andromeda/gcloud/build:/opt/pg/scripts:$PATH"]) 
      {
        stage 'Build'
        //sh 'cd andromeda/gcloud/; mkdir -p build; cd build; cmake ..;'

        stage 'Aurora build'
        echo "Starting aurora build, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH refspec:$GERRIT_REFSPEC"
        //sh "aurora build -p $GERRIT_PROJECT -b $GERRIT_BRANCH -t $JOB_BASE_NAME+$BUILD_NUMBER -r $GERRIT_REFSPEC"
        
        // Aurora build creates a build_id file in WORKSPACE/logs/ the file consists of BUILD ID created by aurora
        if (fileExists ('logs/build_id'))
        {
          // Reading file and extracting build name 
          def string_out = readFile('logs/build_id')
          def build_id = string_out.replace("BUILD-ID=","")
          
          // In case build_id file has empty file
          if (build_id == null)
          {
           error 'Build ID value not found'
          }
          
          // In case no ctest_tag is provided
          if (args.ctest_tag == null)
          {
           error 'No ctest_tag found '
          }
          
          // In case no number of instances specified
          if (args.num_instances == null)
          {
           error 'Number of instances are not defined'
          }
  
          try {
            stage 'test'    
            echo "Starting aurora test, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH ctest_tag:$args.ctest_tag"
            //sh "aurora test -p $GERRIT_PROJECT -b $GERRIT_BRANCH -t $args.ctest_tag -n $args.num_instances -i $iter  '-A $args.test_args' -l $build_id "
          
          } catch (err) {
              echo "Caught: ${err}"
              //currentBuild.result = 'UNSTABLE'
          }
          
          // In case test failed set build status to unstable
          if(fileExists("logs/"))
          {
            echo "exist"
            currentBuild.result = 'UNSTABLE'
          }
          else
          {
            echo "does not exist" 
          }
        }
        else
        {
         error 'Build_id file missing' 
        }
      }
      if (fileExists(archive))
      {
        archiveArtifacts "archive"
      }
      //step([$class: 'WsCleanup']) 
  }
}

