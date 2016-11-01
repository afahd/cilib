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

folder('corelib') {
    displayName('corelib')
    description('pipeplines for corelib')
    folder("corelib/$GERRIT_BRANCH") 
    {
        displayName("$GERRIT_BRANCH")
        description("Pipelines for $GERRIT_BRANCH")
    }
}

def days = 15 

new File("$projectRoot/jenkins/jenkinsfiles").eachFile() { file->
    println "Jenkins File Text:"
    println file.text
    def config = new ConfigSlurper().parse(file.text)
    if (config.containsKey("aurora")) {
        println "Going to generate aurora based job:$config.aurora.name"
        pipelineJob("corelib/$GERRIT_BRANCH/$config.aurora.name") {
            int daysToKeep = valueExist(days,config.aurora.days_to_keep)
            println daysToKeep
            logRotator(daysToKeep.toInteger(),-1,-1,-1)
            definition {
                cpsScm {
                    scm {
                        git {
                            remote {
                                name(GERRIT_PROJECT)
                                url(repoUrl)
                            }
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
                                excludeDrafts("True")
                                excludeTrivialRebase("False")
                                excludeNoCodeChange("True")
                            }
                        }
                        GerritTrigger << gerritProjects {
                            'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.data.GerritProject' {
                                compareType("PLAIN")
                                pattern(GERRIT_PROJECT)
                                branches{
                                    'com.sonyericsson.hudson.plugins.gerrit.trigger.hudsontrigger.data.Branch' {
                                        compareType("REG_EXP")
                                        pattern(".*")

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
    if (argument != null)
    {
        return argument
    }
    else
    {
        return orignal_value
    }
}
