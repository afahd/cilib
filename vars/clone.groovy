import java.nio.charset.StandardCharsets

@Grab(group='org.yaml', module='snakeyaml', version='1.17')
import org.yaml.snakeyaml.*

@NonCPS
def git_clone(Map<String, Object> data)
{   String project;
    String location;
    String branch;
    String build;
    println("here")
    Set s1 = data.keySet()
    println(s1.size())
 
    for (int num=0;num<2;num++)
    {
        project = s1.toList()[num];
        //println(project)
        location = data.get(project)['location'];
        branch = data.get(project)['branch'];
        build = data.get(project)['build'];
        String git_url = location.replace("[","").replace("]","")
        //println(git_url)
        String git_branch = branch.replace("[","").replace("]","")
        //println(git_branch)
        echo "Cloning dependencies for $project "
        //clonning(git_branch,git_url)
        //git branch: 'git_branch', url: "git_url"
    }
}


def clone()
{
    echo "hello there "
    String input2 = readFile 'dependencies.yaml'
    println(input2)
    //InputStream input = new ByteArrayInputStream(input2.getBytes(StandardCharsets.UTF_8));
    //println(input)
   
    Yaml yaml = new Yaml();
    Map<String, Object> yaml_map = new HashMap<String, Object>(yaml.load(input2));
    println("this is after")
    println(yaml_map);
    git_clone(yaml_map) 
}

return this;
