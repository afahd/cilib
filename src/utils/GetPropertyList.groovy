package utils;

def GetPropertyList(java.util.LinkedHashMap conf) {
	// Define the constant properties
	def projectProperties = []
	// Save artifacts for 15 days
	projectProperties.add(buildDiscarder(logRotator(daysToKeepStr: '15')))
	// Add properties for gerrit trigger
	if (conf.type == 'review') {
		projectProperties.add(pipelineTriggers([gerrit( gerritProjects: [[branches: [[compareType: 'REG_EXP', pattern: '.*']],
		 compareType: 'PLAIN', pattern: '$env.GERRIT_PROJECT', filePaths: [[compareType: 'REG_EXP', pattern: '${conf.trigger_path}']]]],
		 triggerOnEvents: [commentAddedContains('.*runpipeline: ${conf.name}.*'), patchsetCreated(excludeDrafts: true, excludeNoCodeChange: true, excludeTrivialRebase: false)])]))
	}
	return projectProperties;
}


return this