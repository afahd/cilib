#!groovy

// Importing Config Slurper using grapes
@Grab(group='org.apache.commons', module='commons-io', version='1.3.2')

def sout = new StringBuilder(), serr= new StringBuilder()

// Clone Project, according to Gerrit Trigger
def repoUrl = "$GERRIT_SCHEME://afahd@$GERRIT_HOST:$GERRIT_PORT/$GERRIT_PROJECT"
def projectRoot = WORKSPACE + "/$GERRIT_PROJECT/"
def clone = "git clone $repoUrl".execute(null, new File(WORKSPACE + "/"))
clone.consumeProcessOutput(sout, serr)
clone.waitFor()

// Fetch and Checkout commit with Jenkins file
def fetch = "git fetch $repoUrl $GERRIT_REFSPEC".execute(null, new File(projectRoot))
fetch.consumeProcessOutput(sout, serr)
fetch.waitFor()
def checkout = "git checkout FETCH_HEAD".execute(null, new File(projectRoot))
checkout.consumeProcessOutput(sout, serr)
checkout.waitFor()
println "out> $sout err> $serr"

// Creating Folders in Jenkins
// GERRIT_PROJECT --> GERRIT_BRANCH --> jobs
folder("$GERRIT_PROJECT") {
    displayName("$GERRIT_PROJECT")
    description("pipeplines for $GERRIT_PROJECT")
}
folder("$GERRIT_PROJECT/$GERRIT_BRANCH")
{
    displayName("$GERRIT_BRANCH")
    description("Pipelines for $GERRIT_PROJECT and branch: $GERRIT_BRANCH")
}

// Initializing values
def days = 15
def exc_drafts = "true"
def exc_triv_rebase = "false"
def exc_no_code_chng = "true"
boolean voting = true
def voting_status=""
def email = ""

// Reading ci enabled list and extracting emails of owners
def ci_list = readFileFromWorkspace('ci_enabled.list')
String[] split_file = ci_list.split(System.getProperty("line.separator"));
for (def line:split_file)
{
    if (line.contains("$GERRIT_PROJECT $GERRIT_BRANCH"))
    {
        String[] line_split = line.split(" ")
        email = line_split.getAt(2)
    }
}

// Iterating over all jenkinsfiles in the directory
new File("$projectRoot/jenkins/jenkinsfiles").eachFile() { file->
    println "Jenkins File Text:"
    println file.text

    // Loading jenkinsfile as config using ConfigSlurper
    def config = new ConfigSlurper().parse(file.text)
    // Looks for aurora closure in jenkins file
    // TODO: Add closure for physical pipelines
    if (config.containsKey("aurora")) {
        println "Going to generate aurora based job:$config.aurora.name"
        // Creating pipeline job
        pipelineJob("$GERRIT_PROJECT/$GERRIT_BRANCH/$config.aurora.name") {
            // Checking if days_to_keep_builds exist in jenkinsfile or use default value
            def daysToKeep = valueExist(days,config.aurora.days_to_keep_builds)
            logRotator(daysToKeep,-1,-1,-1)
            // Block for review pipelines
            // TODO: Periodic pipeline triggers
            if( config.aurora.type == "review" )
            {
                definition
                {
                    cpsScm {
                        scm {
                            git {
                                remote {
                                    name(GERRIT_PROJECT)
                                    url(repoUrl)
                                }
                                branch (GERRIT_BRANCH)
                                extensions {
                                    choosingStrategy {
                                        gerritTrigger()
                                    }
                                }
                            }
                        }
                        // Adding Jenkinsfile script path to be used by the new job
                        scriptPath("jenkins/jenkinsfiles/" + org.apache.commons.io.FilenameUtils.getBaseName(file.name))
                    }
                }
                triggers
                {
                    // Adding triggers to be used in review pipeline
                    gerrit
                    {
                        configure { GerritTrigger ->
                            GerritTrigger / 'triggerOnEvents' {
                                'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.events.PluginCommentAddedContainsEvent' {
                                    // Trigger event for comment added
                                    // Adding runpipeline: <pipeline-name>
                                    commentAddedCommentContains(".*runpipeline: ${config.aurora.name}.*")
                                }
                                'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.events.PluginPatchsetCreatedEvent' {
                                    // Using default values if jenkinsfile does not specify
                                    excludeDrafts(valueExist(exc_drafts, config.aurora.exclude_drafts))
                                    excludeTrivialRebase(valueExist(exc_triv_rebase, config.aurora.exclude_trivialrebase))
                                    excludeNoCodeChange(valueExist(exc_no_code_chng, config.aurora.exclude_nocodechange))
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
                                    if (!config.aurora.trigger_path.isEmpty()) {
                                        filePaths {
                                            'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.data.FilePath' {
                                                compareType("REG_EXP")
                                                pattern(config.aurora.trigger_path)
                                            }
                                        }
                                    }
                                }
                            }
                            GerritTrigger << skipVote {
                                // Set pipeline voting or non voting
                                // Job set as non voting by default
                                if (!config.aurora.voting.isEmpty())
                                {
                                    voting = !config.aurora.voting.toBoolean()
                                }
                                if (voting)
                                {
                                    voting_status = " ***[NON-VOTING]*** "
                                }
                                // Skip vote when voting set to false
                                onSuccessful(voting)
                                onFailed(voting)
                                onUnstable(voting)
                                onNotBuilt(voting)
                            }
                            // Assigning custom build message to be posted to gerrit
                            GerritTrigger << buildFailureMessage("build FAILED (see extended build output for details) ${voting_status} Contact [Pipeline Owners: $email] or comment runpipeline: ${config.aurora.name} to re-trigger the pipeline")
                            GerritTrigger << buildSuccessfulMessage("SUCCESS (see extended build output for details)")
                            GerritTrigger << buildNotBuiltMessage("NOT BUILT")
                            GerritTrigger << buildUnstableMessage("UNSTABLE (see extended build output for details)")
                        }
                    }
                }
            }
            if( config.aurora.type == "periodic" )
            {
                definition
                {
                    cpsScm {
                        scm {
                            git {
                                remote {
                                    name(GERRIT_PROJECT)
                                    url(repoUrl)
                                }
                                branch(GERRIT_BRANCH)
                            }
                        }
                        // Adding Jenkinsfile script path to be used by the new job
                        scriptPath("jenkins/jenkinsfiles/" + org.apache.commons.io.FilenameUtils.getBaseName(file.name))
                    }
                }
                triggers
                {
                    scm(config.aurora.cron)
                }
                parameters
                {
                    stringParam("GERRIT_PROJECT","$GERRIT_PROJECT")
                    stringParam("GERRIT_BRANCH","$GERRIT_BRANCH")
                }
            }
        }
    }
}

// Returns argument if provided or provides orignal_value
def valueExist(def orignal_value, def argument)
{
    if (argument.isEmpty())
    {
         return orignal_value
    }
    else
    {
        return argument
    }
}
