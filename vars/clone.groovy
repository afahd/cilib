import java.nio.charset.StandardCharsets

@Grab(group='org.yaml', module='snakeyaml', version='1.17')
import org.yaml.snakeyaml.*

public class Dependency {
    public LinkedHashMap h1;
    Dependency(LinkedHashMap h1) {
        this.h1 = h1
    }
}
def clone()
{

    String input2 = readFile 'dependencies.yaml'
    println(input2)
    InputStream input = new ByteArrayInputStream(input2.getBytes(StandardCharsets.UTF_8));
    println(input)
   
    Yaml yaml = new Yaml();
    String project;
    String location;
    String branch;
    String build;
    Map<String, Object> data = new HashMap<String, Object>(yaml.load(input));
    Set s1 = data.keySet()
    for (int num=0;num<s1.size();num++)
    {
        project = s1.toArray()[num];
        location = data.get(project)['location'];
        branch = data.get(project)['branch'];
        build = data.get(project)['build'];
        //echo "Cloning dependencies for $project "
        //git branch: branch, url: location
    }
}

return this;
