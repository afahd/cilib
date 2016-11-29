#!groovy

def call(body) {

  def args = [:]
  body.resolveStrategy = Closure.DELEGATE_FIRST
  body.delegate = args
  body()

  // Default Values
  def snapshot = "false"
  def artifacts = "logs/"
  def time = 60
  def target = "default"
  def instances = 1
  def test_args = ""
  def archive_logs = ""
  // Loading Jenkins library
  def lib = new utils.JenkinsLibrary()

  if (args.archive)
  {
    archive_logs = "-a ${args.archive}"
  }
  time = lib.valueExist(time, args.timeout)
  target = lib.valueExist(target, args.target)
  instances = lib.valueExist(instances, args.num_instances)
  snapshot = lib.valueExist(snapshot, args.snapshot)

  if ( snapshot == "false" && instances > 1 )
  {
    error "Set snapshot to 'true' for multiple instances"
  }

  def snapshot_args = ''
  if ( snapshot == "false" )
  {
    snapshot_args = "-K"
  }

  if ( args.test_args != null )
  {
    test_args = "-A \"$args.test_args\""
  }

  if (!(args.test_type in ['ctest', 'plain']))
  {
    error "Unsupported test_type:$args.test_type, exiting"
  }

  


  node('slave-cloud2')
  {
    timeout(time)
    {
      step([$class: 'WsCleanup'])
      stage 'Clone'

      dir('andromeda')
      {
        git branch: 'master', url: 'ssh://gerrit.plumgrid.com:29418/andromeda'
       
        
      }

      withEnv(["PATH=/home/plumgrid/google-cloud-sdk/bin:$WORKSPACE/andromeda/gcloud/build/aurora:$WORKSPACE/andromeda/gcloud/build/aurora/pipeline_scripts:$PATH"])
      {
        sh 'cd andromeda/gcloud/; mkdir -p build; cd build; cmake ..;'
        sh "touch $WORKSPACE/status-message.log"
        stage 'Build'
       
        // Aurora build creates a build_id file in WORKSPACE/logs/ the file consists of BUILD ID created by aurora
        
          

          try
          {
            stage 'Test'
            echo "Starting aurora test, test_type:$args.test_type test_cmd:$args.test_cmd archive: $archive_logs"
            sh "aurora test -t $args.test_type $test_args -c \"$args.test_cmd\" $archive_logs"

          } catch (err)
          {
              lib.errorMessage("Aurora Test failed with: ${err}")
              currentBuild.result = 'UNSTABLE'
              sh "aurora cleanup $instance_id"
          }
        
        
      }
      def status = readFile "$WORKSPACE/status-message.log"
      setGerritReview unsuccessfulMessage: "$status"
      
      archiveArtifacts allowEmptyArchive: true, artifacts: artifacts
      step([$class: 'WsCleanup'])
    }
  }
}
