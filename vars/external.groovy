// Importing Config Slurper using grapes
@Grab(group='org.apache.commons', module='commons-io', version='1.3.2')
def call(body) {
    // evaluate the body block, and collect configuration into the object
    def config = [:]
    body.resolveStrategy = Closure.DELEGATE_FIRST
    body.delegate = config
    body()
    println "Config"
    node('master') {
      git 'ssh://afahd@192.168.10.77:29418/phoenix.git'
      aurora({ archive = "test123"})
    }
}
