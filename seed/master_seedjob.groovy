#!groovy

// Importing Config Slurper using grapes
@Grab(group='org.apache.commons', module='commons-io', version='1.3.2')

def sout = new StringBuilder(), serr= new StringBuilder()
def repoUrl = "$GERRIT_SCHEME://afahd@$GERRIT_HOST:$GERRIT_PORT/$GERRIT_PROJECT"

def ci_list = readFileFromWorkspace('ci_enabled.list')
String[] split_file = ci_list.split(System.getProperty("line.separator"));

def gerrit_url = "ssh://gerrit.plumgrid.com:29418/"

for (def line:split_file)
{
    String[] line_split = line.split(" ")
    repourl = line_split.getAt(0)
    repo = "${repourl}" - "${gerrit_url}"
    branch = line_split.getAt(1)
    email = line_split.getAt(2)

    println "${repo}, ${branch}, ${email}"
}

freeStyleJob('ci_seed_job_irfan_test') {
    logRotator(-1, 10)

    scm {
        git {
            remote {
                name(GERRIT_PROJECT)
                url(repoUrl)
            }
            branch (GERRIT_BRANCH)
        }
    }

    triggers {
        // Adding triggers to be used in review pipeline
        gerrit
        {
            configure { GerritTrigger ->
                GerritTrigger / 'triggerOnEvents' {
                    'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.events.PluginCommentAddedContainsEvent' {
                        // Trigger event for comment added
                        // Adding runpipeline: <pipeline-name>
                        commentAddedCommentContains(".*runpipeline: master_seed_job")
                    }
                    'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.events.PluginPatchsetCreatedEvent' {
                        // Using default values if jenkinsfile does not specify
                        excludeDrafts("True")
                        excludeTrivialRebase("False")
                        excludeNoCodeChange("True")
                    }
                }




                GerritTrigger << gerritProjects {
                    // Adding gerrit projects for gerrit trigger using GERRIT PROJECT and GERRIT_BRANCH
                    'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.data.GerritProject' {
                        compareType("PLAIN")
                        pattern(GERRIT_PROJECT)
                        branches{
                            'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.data.Branch' {
                                compareType("PLAIN")
                                pattern(GERRIT_BRANCH)
                            }
                        }
                        // In case value for trigger path provided set trigger file path
                        filePaths {
                            'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.data.FilePath' {
                                compareType("ANT")
                                pattern("jenkins/jenkinsfiles/**")
                            }
                        }
                    }
                }
            }
        }
    }

//    steps {
//        gradle('clean build')
//    }
//    publishers {
//        archiveArtifacts('job-dsl-plugin/build/libs/job-dsl.hpi')
//    }
}

// Clone Project, according to Gerrit Trigger
//def repoUrl = "$GERRIT_SCHEME://$GERRIT_HOST:$GERRIT_PORT/$GERRIT_PROJECT"
//def projectRoot = WORKSPACE + "/$GERRIT_PROJECT/"
//def clone = "git clone $repoUrl".execute(null, new File(WORKSPACE + "/"))
//clone.consumeProcessOutput(sout, serr)
//clone.waitFor()

// Fetch and Checkout commit with Jenkins file
//def fetch = "git fetch $repoUrl $GERRIT_REFSPEC".execute(null, new File(projectRoot))
//fetch.consumeProcessOutput(sout, serr)
//fetch.waitFor()
//def checkout = "git checkout FETCH_HEAD".execute(null, new File(projectRoot))
//checkout.consumeProcessOutput(sout, serr)
//checkout.waitFor()
//println "out> $sout err> $serr"

// Creating Folders in Jenkins
// GERRIT_PROJECT --> GERRIT_BRANCH --> jobs
//folder("$GERRIT_PROJECT") {
//    displayName("$GERRIT_PROJECT")
//    description("pipeplines for $GERRIT_PROJECT")
//}
//folder("$GERRIT_PROJECT/$GERRIT_BRANCH")
//{
//    displayName("$GERRIT_BRANCH")
//    description("Pipelines for $GERRIT_PROJECT and branch: $GERRIT_BRANCH")
//}

// Initializing values
def days = 15
def exc_drafts = "true"
def exc_triv_rebase = "false"
def exc_no_code_chng = "true"
boolean voting = true
def voting_status=""
def email = ""

// Reading ci enabled list and extracting emails of owners
// def ci_list = readFileFromWorkspace('ci_enabled.list')
// String[] split_file = ci_list.split(System.getProperty("line.separator"));
// for (def line:split_file)
// {
//     if (line.contains("$GERRIT_PROJECT $GERRIT_BRANCH"))
//    {
//        String[] line_split = line.split(" ")
//        email = line_split.getAt(2)
//    }
//}

