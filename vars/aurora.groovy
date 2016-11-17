#!groovy

def call(body) {

  def args = [:]
  body.resolveStrategy = Closure.DELEGATE_FIRST
  body.delegate = args
  body()

  // Default Values
  def archive = "logs/"
  def time = 60
  def target = "default"
  def instances = 1
  def test_args = ""
  // Loading Jenkins library
  def lib = new utils.JenkinsLibrary()

  archive = lib.valueExist(archive, args.archive)
  time = lib.valueExist(time, args.timeout)
  target = lib.valueExist(target, args.target)
  instances = lib.valueExist(instances, args.num_instances)

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
      stage 'Clone'

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
        stage 'Build'
        sh 'cd andromeda/gcloud/; mkdir -p build; cd build; cmake ..;'
        sh "touch $WORKSPACE/status-message.log"
        stage 'Aurora build'
        try
        {
          if (args.type == 'review')
          {
            echo "Starting aurora build, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH refspec:$GERRIT_REFSPEC tag:$JOB_BASE_NAME-$BUILD_NUMBER target: $target"
            sh "aurora build -p $GERRIT_PROJECT -b $GERRIT_BRANCH -t $JOB_BASE_NAME-$BUILD_NUMBER -r $GERRIT_REFSPEC -T $target"
          }
          else
          {
            echo "Starting aurora build, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH tag:$JOB_BASE_NAME-$BUILD_NUMBER target: $target"
            sh "aurora build -p $GERRIT_PROJECT -b $GERRIT_BRANCH -t $JOB_BASE_NAME-$BUILD_NUMBER -T $target"
          }
        }
        catch (error)
        {
          lib.errorMessage("Aurora build failed with: $error, Cleaning up instances")
          sh "aurora cleanup $JOB_BASE_NAME-$BUILD_NUMBER"
        }
        // Aurora build creates a build_id file in WORKSPACE/logs/ the file consists of BUILD ID created by aurora
        if (fileExists ('logs/build_id'))
        {
          // Reading file and extracting build name
          def string_out = readFile('logs/build_id')
          def build_id = string_out.replace("BUILD-ID=","")

          // In case build_id file has empty file
          if (build_id == null)
          {
            lib.errorMessage("Build ID value not found")
          }

          try
          {
            stage 'test'
            echo "Starting aurora test, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH test_type:$args.test_type test_cmd:$args.test_cmd"
            sh "aurora test -p $GERRIT_PROJECT -b $GERRIT_BRANCH -t $args.test_type $test_args -c \"$args.test_cmd\" -n $instances -l $build_id"

          } catch (err)
          {
              lib.errorMessage("Aurora Test failed with: ${err}")
              currentBuild.result = 'UNSTABLE'
              sh "aurora cleanup $build_id"
          }
        }
        else
        {
          lib.errorMessage("Build_id file missing")
        }
      }
      def status = readFile "$WORKSPACE/status-message.log"
      lib.sendEmail(currentBuild.result,"$email")
      archiveArtifacts allowEmptyArchive: true, artifacts: archive
      step([$class: 'WsCleanup'])
    }
  }
}
