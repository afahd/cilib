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
       Yaml yaml = new Yaml();
       String project;
       String location;
       String branch;
       String build;
       String workingDir = System.getProperty("user.dir");
       println(workingDir)
            
    
        println('asdasdasd')
        def a = readFile 'dependencies.yaml'
        println(a)
        println('defefefef')
        def b = readFile 'depende1ncies.yaml'
        println(b)
      
    
}
return this;
