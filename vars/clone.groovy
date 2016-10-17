import java.nio.charset.StandardCharsets

@Grab(group='org.yaml', module='snakeyaml', version='1.17')
import org.yaml.snakeyaml.*

@NonCPS
def clone()
{
    echo "hello there "
    String input2 = readFile 'dependencies.yaml'
    println(input2)
    InputStream input = new ByteArrayInputStream(input2.getBytes(StandardCharsets.UTF_8));
    println(input)
   
    Yaml yaml = new Yaml();
    String project;
    String location;
    String branch;
    String build;
    echo "this is safe"
    Map<String, Object> data = new HashMap<String, Object>(yaml.load(input));
    echo "$data"
   
    Set s1 = data.keySet()
    echo "testing"
    
    for (int num=0;num<s1.size();num++)
    {
        project = s1.toArray()[num];
        location = data.get(project)['location'];
        branch = data.get(project)['branch'];
        build = data.get(project)['build'];
        echo "Cloning dependencies for $project "
        git branch: branch, url: location
    }
}

return this;
