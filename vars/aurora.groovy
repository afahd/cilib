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
  
  def a = new utils.JenkinsLibrary()
  
  a.checkGerritArguments


  // // Check if number of iterations given
  // if (args.iterations != null)
  // {
  //   iter = args.iterations
  // }

  // // Check if artifacts to archive given
  // if (args.archive != null)
  // {
  //   archive = args.archive
  // }

  // // Check if timeout to archive given
  // if (args.timeout != null)
  // {
  //   time = args.timeout
  // }

  // if (args.type == 'review')
  // {
  //   // Check if no empty variable exists
  //   if (GERRIT_REFSPEC == null)
  //   {
  //    error 'No GERRIT_REFSPEC found'
  //   }
  //   if (GERRIT_BRANCH == null)
  //   {
  //    error 'No GERRIT_BRANCH found'
  //   }
  //   if (GERRIT_PROJECT == null)
  //   {
  //    error 'No GERRIT_PROJECT found'
  //   }
  // }

  // node('slave-cloud')
  // {
  //   timeout(time)
  //   {
  //     step([$class: 'WsCleanup'])
  //     stage 'Clone'

  //     dir('andromeda')
  //     {
  //       git branch: 'master', url: 'ssh://gerrit.plumgrid.com:29418/andromeda'
  //     }

  //     withEnv(["PATH=/home/plumgrid/google-cloud-sdk/bin:$WORKSPACE/andromeda/gcloud/build:/opt/pg/scripts:$PATH"])
  //     {
  //       stage 'Build'
  //       sh 'cd andromeda/gcloud/; mkdir -p build; cd build; cmake ..;'

  //       stage 'Aurora build'
  //       echo "Starting aurora build, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH refspec:$GERRIT_REFSPEC tag:$JOB_BASE_NAME+$BUILD_NUMBER"

  //       try
  //       {
  //         sh "aurora build -p $GERRIT_PROJECT -b $GERRIT_BRANCH -t $JOB_BASE_NAME+$BUILD_NUMBER -r $GERRIT_REFSPEC"
  //       }
  //       catch (error)
  //       {
  //         echo "Aurora Build Failed! Cleaning up instances"
  //         sh "aurora cleanup $JOB_BASE_NAME+$BUILD_NUMBER"
  //       }

  //       // Aurora build creates a build_id file in WORKSPACE/logs/ the file consists of BUILD ID created by aurora
  //       if (fileExists ('logs/build_id'))
  //       {
  //         // Reading file and extracting build name
  //         def string_out = readFile('logs/build_id')
  //         def build_id = string_out.replace("BUILD-ID=","")

  //         // In case build_id file has empty file
  //         if (build_id == null)
  //         {
  //          error 'Build ID value not found'
  //         }

  //         // In case no ctest_tag is provided
  //         if (args.ctest_tag != null)
  //         {
  //           // In case no number of instances specified
  //           if (args.num_instances == null)
  //           {
  //            error 'Number of instances are not defined'
  //           }

  //           try
  //           {
  //             stage 'test'
  //             echo "Starting aurora test, project:$GERRIT_PROJECT, branch:$GERRIT_BRANCH ctest_tag:$args.ctest_tag"
  //             sh "aurora test -p $GERRIT_PROJECT -b $GERRIT_BRANCH -t $args.ctest_tag -n $args.num_instances -i $iter  '-A $args.test_args' -l $build_id "

  //           } catch (err)
  //           {
  //               echo "Aurora Test failed with: ${err}"
  //               currentBuild.result = 'UNSTABLE'
  //               sh "aurora cleanup $build_id"
  //           }
  //         }
  //         else
  //         {
  //           echo "Aurora Test did not start since no test tag provided"
  //         }
  //       }
  //       else
  //       {
  //        error 'Build_id file missing'
  //       }
  //     }
  //     archiveArtifacts allowEmptyArchive: true, artifacts: archive
  //     step([$class: 'WsCleanup'])
  //   }
  // }
}
