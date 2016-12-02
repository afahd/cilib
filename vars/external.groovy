// Importing Config Slurper using grapes
@Grab(group='org.apache.commons', module='commons-io', version='1.3.2')
def call(body) {
    // evaluate the body block, and collect configuration into the object
    def config = [:]
    body.resolveStrategy = Closure.DELEGATE_FIRST
    body.delegate = config
    body()
    def test_project= config.location.split('/')[-1].minus(".git")
    print test_project
    node('master') {
        git branch:config.branch, url:config.location
        withEnv( ["TEST_PROJECT=$test_project"]) 
        {
          load("jenkins/jenkinsfiles/$config.pipeline_name")  
        }
    }
}
