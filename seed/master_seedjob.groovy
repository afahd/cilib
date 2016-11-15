#!groovy

def sout = new StringBuilder(), serr= new StringBuilder()
// Clone Project, according to Gerrit Trigger
def repoUrl = "$GERRIT_SCHEME://afahd@$GERRIT_HOST:$GERRIT_PORT/$GERRIT_PROJECT"
def projectRoot = WORKSPACE 

// Fetch and Checkout commit with Jenkins file
def fetch = "git fetch $repoUrl $GERRIT_REFSPEC".execute(null, new File(projectRoot))
fetch.consumeProcessOutput(sout, serr)
fetch.waitFor()
def checkout = "git checkout FETCH_HEAD".execute(null, new File(projectRoot))
checkout.consumeProcessOutput(sout, serr)
checkout.waitFor()
println "out> $sout err> $serr"

// Reading through the ci_enablied.list
def ci_list = readFileFromWorkspace('ci_enabled.list')
String[] split_file = ci_list.split(System.getProperty("line.separator"));

// Creating a free style job named ci_seed_job
freeStyleJob('master_ci_seed_job') {
    // Adding the days for which to keep records of the builds
    logRotator(15,-1,-1,-1)

    // Adding the Source code managment
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
        // Adding gerrit triggers to be used
        gerrit
        {
            configure { GerritTrigger ->
                GerritTrigger / 'triggerOnEvents' {
                    'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.events.PluginCommentAddedContainsEvent' {
                        // Trigger event for comment added
                        // Adding runpipeline: <pipeline-name>
                        commentAddedCommentContains(".*runpipeline: master_ci_seed_job.*")
                    }
                    'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.events.PluginPatchsetCreatedEvent' {
                        // Using default values if jenkinsfile does not specify
                        excludeDrafts("True")
                        excludeTrivialRebase("False")
                        excludeNoCodeChange("False")
                    }
                }

                // Iterating over the projects in the ci_enabled.list
                GerritTrigger << gerritProjects {
                    for (def line:split_file)
                    {
                        String[] line_split = line.split(" ")
                        repourl = line_split.getAt(0)
                        // Extracting the project name by removing the ssh://gerrit.plumgrid.com:29418/
                        int idx = repourl.lastIndexOf('/')
                        repo = repourl.substring(idx + 1)
                        branch = line_split.getAt(1)
                        println "${repo}, ${branch}"
                        // Adding gerrit project and gerrit branch for gerrit trigger from the ci_enabled.list
                        'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.data.GerritProject' {
                            compareType("PLAIN")
                            pattern(repo)
                            branches{
                                'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.data.Branch' {
                                    compareType("PLAIN")
                                    pattern(branch)
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
    }
    // Adding dsl seed job
    steps {
        dsl{
            external('seed/seedjob.groovy')
        }
    }
}
