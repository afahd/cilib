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

def cloneDependencies()
{
    // Built in readFile for groovy that read a file and returns a string
    String dep_input = readFile 'dependencies.yaml'
    List project_list = getProjects(dep_input)
    for(int i=0; i<project_list.size();i++)
    {
        location = getLocation(project_list.get(i),dep_input)
        branch = getBranch(project_list.get(i),dep_input)
        echo "Cloning dependencies from $location "
        // built in git function to clone a repository
        git branch: "$branch", url: "$location"
    }
}

return this;
