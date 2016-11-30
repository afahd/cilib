#!groovy

def call(body) {

  def args = [:]
  body.resolveStrategy = Closure.OWNER_FIRST
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
    echo "Archive: $archive_logs"
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

  if (args.type == 'review')
  {
    lib.checkGerritArguments()
  }

  node('slave-cloud2')
  {
    timeout(time)
    {
      step([$class: 'WsCleanup'])
      stage 'Pre-init'

      dir('andromeda')
      {
        git branch: 'master', url: 'ssh://gerrit.plumgrid.com:29418/andromeda'

        def ci_list = readFile 'ci_enabled.list'
        String[] split_file = ci_list.split(System.getProperty("line.separator"));
        for (def line:split_file)
        {
            if (line.contains("$GERRIT_PROJECT $GERRIT_BRANCH"))
            {
                String[] line_split = line.split(" ")
                email = line_split.getAt(2)
            }
        }
      }

      withEnv(["PATH=/home/plumgrid/google-cloud-sdk/bin:$WORKSPACE/andromeda/gcloud/build/aurora:$WORKSPACE/andromeda/gcloud/build/aurora/pipeline_scripts:$PATH"])
      {
        sh 'cd andromeda/gcloud/; mkdir -p build; cd build; cmake ..;'
        sh "touch $WORKSPACE/status-message.log"
        stage 'Build'
        try
        {
          def build_tag = "${JOB_BASE_NAME}${BUILD_NUMBER}"
          if (args.type == 'review')
          {
            echo "Starting aurora build, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH refspec:$GERRIT_REFSPEC tag:$build_tag target: $target"
            sh "aurora build -p $GERRIT_PROJECT -b $GERRIT_BRANCH -t $build_tag -r $GERRIT_REFSPEC -T $target $snapshot_args"
          }
          else
          {
            echo "Starting aurora build, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH tag:$build_tag target: $target"
            sh "aurora build -p $GERRIT_PROJECT -b $GERRIT_BRANCH -t $build_tag -T $target $snapshot_args"
          }
        }
        catch (error)
        {
          lib.errorMessage("Aurora build failed with: $error, Cleaning up instances")
          sh "aurora cleanup $build_tag"
        }
        // Aurora build creates a build_id file in WORKSPACE/logs/ the file consists of BUILD ID created by aurora
        if (fileExists ('logs/instance-id'))
        {
          def instance_id_cmd = ''
          def instance_id = ''
          // Reading file and extracting build name
          def string_out = readFile('logs/instance-id')

          if (string_out.startsWith("BUILD-ID"))
          {
            instance_id_cmd = string_out.replace("BUILD-ID=",'-l ')
            instance_id = string_out.replace("BUILD-ID=",'')
          }
          else if (string_out.startsWith("INSTANCE-ID"))
          {
            instance_id_cmd = string_out.replace("INSTANCE-ID=",'-i ')
            instance_id = string_out.replace("INSTANCE-ID=",'')
          }
          else
          {
            lib.errorMessage("INSTANCE ID value not found")
          }

          try
          {
            stage 'Test'
            echo "Starting aurora test, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH test_type:$args.test_type test_cmd:$args.test_cmd instance_id:$instance_id_cmd"
            sh "aurora test -p $GERRIT_PROJECT -b $GERRIT_BRANCH -t $args.test_type $test_args -c \"$args.test_cmd\" -n $instances $archive_logs $instance_id_cmd "

          } catch (err)
          {
              lib.errorMessage("Aurora Test failed with: ${err}")
              currentBuild.result = 'UNSTABLE'
              sh "aurora cleanup $instance_id"
          }
        }
        else
        {
          lib.errorMessage("Instance_id file missing")
        }
      }
      def status = readFile "$WORKSPACE/status-message.log"
      setGerritReview unsuccessfulMessage: "$status"
      lib.sendEmail(currentBuild.result,"$email")
      archiveArtifacts allowEmptyArchive: true, artifacts: artifacts
      step([$class: 'WsCleanup'])
    }
  }
}
