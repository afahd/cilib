#!groovy

@Grab(group='org.apache.commons', module='commons-io', version='1.3.2')

def sout = new StringBuilder(), serr= new StringBuilder()
def repoUrl = "$GERRIT_SCHEME://afahd@$GERRIT_HOST:$GERRIT_PORT/$GERRIT_PROJECT"
def projectRoot = WORKSPACE + "/$GERRIT_PROJECT/"
def clone = "git clone $repoUrl".execute(null, new File(WORKSPACE + "/"))
clone.consumeProcessOutput(sout, serr)
clone.waitFor()
def fetch = "git fetch $repoUrl $GERRIT_REFSPEC".execute(null, new File(projectRoot))
fetch.consumeProcessOutput(sout, serr)
fetch.waitFor()

def checkout = "git checkout FETCH_HEAD".execute(null, new File(projectRoot))
checkout.consumeProcessOutput(sout, serr)
checkout.waitFor()
println "out> $sout err> $serr"

folder("$GERRIT_PROJECT") {
    displayName("$GERRIT_PROJECT")
    description("pipeplines for $GERRIT_PROJECT")
    folder("$GERRIT_PROJECT/$GERRIT_BRANCH") 
    {
        displayName("$GERRIT_BRANCH")
        description("Pipelines for $GERRIT_PROJECT and branch: $GERRIT_BRANCH")
    }
}

def days = 15 
def exc_drafts = "true"
def exc_triv_rebase = "false"
def exc_no_code_chng = "true"
def email = ""

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
println email

new File("$projectRoot/jenkins/jenkinsfiles").eachFile() { file->
    println "Jenkins File Text:"
    println file.text
    def config = new ConfigSlurper().parse(file.text)
    println "testing"
    println config.aurora.days_to_kepp.isEmpty()
    if (config.containsKey("aurora")) {
        println "Going to generate aurora based job:$config.aurora.name"
        pipelineJob("$GERRIT_PROJECT/$GERRIT_BRANCH/$config.aurora.name") {
            def daysToKeep = valueExist(days,config.aurora.days_to_keep)
            logRotator(daysToKeep,-1,-1,-1)
            definition {
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
                    scriptPath("jenkins/jenkinsfiles/" + org.apache.commons.io.FilenameUtils.getBaseName(file.name))
                }
            }
            if( config.aurora.type == "review" )
            {
            triggers {
                gerrit {
                    configure { GerritTrigger ->
                        GerritTrigger / 'triggerOnEvents' {
                            'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.events.PluginCommentAddedContainsEvent' {
                                commentAddedCommentContains(".*runpipeline: ${config.aurora.name}.*")
                            }
                            'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.events.PluginPatchsetCreatedEvent' {
                                
                                excludeDrafts(valueExist(exc_drafts, config.aurora.exclude_drafts))
                                excludeTrivialRebase(valueExist(exc_triv_rebase, config.aurora.exclude_trivialrebase))
                                excludeNoCodeChange(valueExist(exc_no_code_chng, config.aurora.exclude_nocodechange))
                            }
                        }
                        GerritTrigger << gerritProjects {
                            'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.data.GerritProject' {
                                compareType("PLAIN")
                                pattern(GERRIT_PROJECT)
                                branches{
                                    'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.data.Branch' {
                                        compareType("PLAIN")
                                        pattern(GERRIT_BRANCH)

                                    }
                                }
                                if ( config.aurora.trigger_path != null ) {
                                    filePaths {
                                        'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.data.FilePath' {
                                            compareType("REG_EXP")
                                            pattern(config.aurora.trigger_path)
                                        }
                                    }
                                }

                            }
                        }
                    }
                }
            }
        }
        }
    }
}

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
