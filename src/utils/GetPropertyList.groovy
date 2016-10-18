package utils;

def GetPropertyList(def config) {
	// Define the constant properties
	def projectProperties = []
	// Save artifacts for 15 days
	projectProperties.add(buildDiscarder(logRotator(daysToKeepStr: '15')))
	// Add properties for gerrit trigger
	if (config.type == 'review') {
		projectProperties.add(pipelineTriggers([gerrit( gerritProjects: [[branches: [[compareType: 'REG_EXP', pattern: '.*']],
		 compareType: 'PLAIN', pattern: '$env.GERRIT_PROJECT', filePaths: [[compareType: 'REG_EXP', pattern: '${config.trigger_path}']]]],
		 triggerOnEvents: [commentAddedContains('.*runpipeline: ${config.name}.*'), patchsetCreated(excludeDrafts: true, excludeNoCodeChange: true, excludeTrivialRebase: false)])]))
	}
	return projectProperties;
}


return this