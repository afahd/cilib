
def call(body) {

  def config = [:]
  body.resolveStrategy = Closure.DELEGATE_FIRST
  body.delegate = config
  body()
  
  if (config.type == 'review'){
    properties([buildDiscarder(logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '15', numToKeepStr: '')),
    <object of type com.suryagaddipati.jenkins.SlaveUtilizationProperty>,
    [$class: 'RebuildSettings', autoRebuild: false, rebuildDisabled: false],
    [$class: 'ThrottleJobProperty', categories: [], limitOneJobWithMatchingParams: false, maxConcurrentPerNode: 0,
      maxConcurrentTotal: 0, paramsToUseForLimit: '', throttleEnabled: false, throttleOption: 'project'],
    pipelineTriggers([gerrit(customUrl: '', gerritProjects: [[branches: [[compareType: 'ANT', pattern: '*']],
      compareType: 'PLAIN', disableStrictForbiddenFileVerification: false,
      pattern: 'jenkinstest', filePaths: [[compareType: 'REG_EXP', pattern: '$config.trigger_path']]]],
      serverName: 'Gerrit Server',
      triggerOnEvents: [patchsetCreated(excludeDrafts: true, excludeNoCodeChange: true, excludeTrivialRebase: false),
       commentAddedContains('.*runpipeline: $config.name.*')])])])
  }
  
  node {
    stage 'build'
    timeout(config.timeout) {
    
      sh 'aurora build -p $GERRIT_PROJECT' -b '$GERRIT_BRANCH' -r '$GERRIT_REFSPEC' -T 'automaton'
      
    
  }
