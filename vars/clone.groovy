import java.nio.charset.StandardCharsets

@Grab(group='org.yaml', module='snakeyaml', version='1.17')
import org.yaml.snakeyaml.*

@NonCPS
List get_project(String s2)
{
    Yaml yaml = new Yaml();
    Map<String, Object> yaml_map = new HashMap<String, Object>(yaml.load(s2));
    List keys = new ArrayList(yaml_map.keySet());
    return keys
}

@NonCPS
String get_location(String proj, String input)
{
    Yaml yaml = new Yaml();
    Map<String, Object> yaml_map = new HashMap<String, Object>(yaml.load(input));
    String git_url = yaml_map.get(proj)['location']
    return git_url.replace("[","").replace("]","")

}

@NonCPS
String get_branch(String proj, String input)
{
    Yaml yaml = new Yaml();
    Map<String, Object> yaml_map = new HashMap<String, Object>(yaml.load(input));
    String git_branch = yaml_map.get(proj)['branch']
    return git_branch.replace("[","").replace("]","")

}    

def clone()
{
    String input2 = readFile 'dependencies.yaml'
   List l1 = get_project(input2)
    for(int i=0; i<l1.size();i++)
    {
        location = get_location(l1.get(i),input2)
        branch = get_branch(l1.get(i),input2)
        echo "Cloning dependencies from $location "
        git branch: 'branch', url: "location"
    }
}

return this;
