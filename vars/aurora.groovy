#!groovy

def call(body) {

  def args = [:]
  body.resolveStrategy = Closure.DELEGATE_FIRST
  body.delegate = args
  body()

  // Default Values
  def iter = 1
  def archive = "logs/"
  def time = 60
  // Loading Jenkins library
  def lib = new utils.JenkinsLibrary()

  iter = lib.valueExist(iter,args.iterations)
  archive = lib.valueExist(archive,args.archive)
  time = lib.valueExist(time,args.timeout)

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
       
        echo "Starting aurora build, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH tag:$JOB_BASE_NAME-$BUILD_NUMBER"
        try
        {
          dir('andromeda/gcloud/build/aurora/')
          {
            sh "aurora build -p $GERRIT_PROJECT -b $GERRIT_BRANCH -t $JOB_BASE_NAME-$BUILD_NUMBER"
          }
        }
        catch (error)
        {
          lib.errorToGerrit("Aurora build failed with: $error, Cleaning up instances")
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
            lib.errorToGerrit("Build ID value not found")
          }

          // In case no ctest_tag is provided
          if (args.ctest_tag != null)
          {
            // In case no number of instances specified
            if (args.num_instances == null)
            {
              lib.errorToGerrit("Number of instances are not defined")
            }

            try
            {
              stage 'test'
              echo "Starting aurora test, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH ctest_tag:$args.ctest_tag"
              sh "aurora test -p $GERRIT_PROJECT -b $GERRIT_BRANCH -t $args.ctest_tag -n $args.num_instances -i $iter  '-A $args.test_args' -l $build_id "

            } catch (err)
            {
                lib.errorToGerrit("Aurora Test failed with: ${err}")
                sh "aurora cleanup $build_id"
                currentBuild.result = 'UNSTABLE'
            }
          }
          else
          {
            lib.errorToGerrit("Aurora Test did not start since no test tag provided")
          }
        }
        else
        {
          lib.errorToGerrit("Build_id file missing")
        }
      }
      lib.sendEmail(currentBuild.result,"$email")
      def status = readFile "$WORKSPACE/status-message.log"
      setGerritReview unsuccessfulMessage: "$status"
      archiveArtifacts allowEmptyArchive: true, artifacts: archive
      step([$class: 'WsCleanup'])
      
    }
  }
}
