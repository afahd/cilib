package utils;

import java.nio.charset.StandardCharsets
// Importing external jar file with the help of grapes
@Grab(group='org.yaml', module='snakeyaml', version='1.17')
import org.yaml.snakeyaml.*

// Any function which does pure groovy related work is marked as NonCP
@NonCPS
List getProjects(String dep_file)
{
    Yaml yaml = new Yaml();
    Map<String, Object> yaml_map = new HashMap<String, Object>(yaml.load(dep_file));
    List projects_list = new ArrayList(yaml_map.keySet());
    return projects_list
}

@NonCPS
String getLocation(String proj, String dep_file)
{
    Yaml yaml = new Yaml();
    Map<String, Object> yaml_map = new HashMap<String, Object>(yaml.load(dep_file));
    String git_url = yaml_map.get(proj)['location']
    // Removing special characters [ and ]
    return git_url.replace("[","").replace("]","")
}

@NonCPS
String getBranch(String proj, String dep_file)
{
    Yaml yaml = new Yaml();
    Map<String, Object> yaml_map = new HashMap<String, Object>(yaml.load(dep_file));
    String git_branch = yaml_map.get(proj)['branch']
    return git_branch.replace("[","").replace("]","")
}

def checkDependency()
{
    return fileExists('dependencies.yaml')
}

List cloneDependencies(String repo)
{
    // Built in readFile for groovy that read a file and returns a string
    dir ("$repo")
    {
        if (checkDependency())
        {
            String dep_input = readFile "dependencies.yaml"
            List project_list = getProjects(dep_input)
            for(int i=0; i<project_list.size();i++)
            {
                def project_name = project_list.get(i)
                location = getLocation(project_name,dep_input)
                branch = getBranch(project_name,dep_input)
                echo "Cloning dependencies from $location "
                sh "mkdir -p $WORKSPACE/$project_name;"
                dir ("$WORKSPACE/$project_name")
                {
                    // built in git function to clone a repository
                    git branch: "$branch", url: "$location"
                }
            }
            return project_list
        }
    }
}

def cloneProject(String repo_name, String repo_url)
{
    sh "mkdir -p $WORKSPACE/$repo_name;"
    dir ("$repo_name")
    {
        git branch: "master", url: "$repo_url"
    }

    List projects = []
    projects.push("$repo_name")

    while(!projects.isEmpty())
    {
        List dependent_list = cloneDependencies(projects.get(0));
        projects.remove(0);
        if(dependent_list != null)
        {
            projects.addAll(dependent_list)
        }
    }
}

def valueExist (def orignal_value, def argument)
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

def checkGerritArguments()
{
    if (GERRIT_REFSPEC == null)
    {
     error 'No GERRIT_REFSPEC found'
    }
    if (GERRIT_BRANCH == null)
    {
     error 'No GERRIT_BRANCH found'
    }
    if (GERRIT_PROJECT == null)
    {
     error 'No GERRIT_PROJECT found'
    }
}

def errorToGerrit(String statement)
{
    echo "$statement"
    def older_data = readFile "$WORKSPACE/status-message.log"
    writeFile file: 'status-message.log', text: "$older_data $statement"
    currentBuild.result = 'FAILURE'
}

return this;
