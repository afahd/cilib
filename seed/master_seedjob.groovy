#!groovy

// Importing Config Slurper using grapes
@Grab(group='org.apache.commons', module='commons-io', version='1.3.2')

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

def ci_list = readFileFromWorkspace('ci_enabled.list')
String[] split_file = ci_list.split(System.getProperty("line.separator"));

def gerrit_url = "ssh://gerrit.plumgrid.com:29418/"

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
                    for (def line:split_file)
                    {
                        String[] line_split = line.split(" ")
                        repourl = line_split.getAt(0)
                        repo = "${repourl}" - "${gerrit_url}"
                        branch = line_split.getAt(1)
                        println "${repo}, ${branch}"
                        // Adding gerrit projects for gerrit trigger using GERRIT PROJECT and GERRIT_BRANCH
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

    steps {
        dsl{
            external('seed/seedjob.groovy')
        }
    }
}
