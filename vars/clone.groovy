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
      
 -    InputStream input2 = readFile 'dependencies.yaml'
 +    String input2 = readFile 'dependencies.yaml'
      println(input2)
      InputStream input = new ByteArrayInputStream(input2.getBytes(StandardCharsets.UTF_8));
      //InputStream input = new FileInputStream(new File(dir+"/dependencies.yaml"));
     Yaml yaml = new Yaml();
     String project;
     String location;
     String branch;
     String build;
     Dependency data = yaml.load(input);
     println(data.h1)
     Set s1 = data.h1.keySet();
     for (int num=0;num<s1.size();num++)
     {
         project = s1.toArray()[num];
         location = data.h1.get(project)['location'];
         branch = data.h1.get(project)['branch'];
         build = data.h1.get(project)['build'];
         echo "Cloning dependencies for $project "
         git branch: branch, url: location
     }
 }
 
 return this;
