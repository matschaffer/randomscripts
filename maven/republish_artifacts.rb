class Artifact
  DEFAULT_REPOSITORY = "http://maven/content/groups/master"
  
  attr_accessor :repository, :group_id, :artifact_id, :packaging, :version
  
  def initialize id, repository = nil
    @repository = repository || DEFAULT_REPOSITORY
    @group_id, @artifact_id, @packaging, @version, @scope = id.split(":")
  end

  def basename packaging = @packaging
    [[artifact_id, version].join('-'), packaging].join('.')
  end
  
  def pom_name
    basename("pom")
  end
  
  def path packaging = @packaging
    [repository, group_id.gsub('.', '/'), artifact_id, version, basename(packaging)].join('/')
  end
  
  def pom_path
    path("pom")
  end
  
  def download uri, file
    puts "Downloading #{uri} to #{file}..."
    system "curl -o #{file} #{uri}"
  end
  
  def redeploy_to repository, repository_id
    download(path, basename)
    download(pom_path, pom_name)
    system "mvn deploy:deploy-file -Durl=#{repository} -DrepositoryId=#{repository_id} -Dfile=#{basename} -DpomFile=#{pom_name}"
  end
  
  def to_s
    "#{group_id}:#{artifact_id}:#{packaging}:#{version}"
  end
  
  # for Array.uniq support
  def hash
    to_s.hash
  end
  
  def eql? other
    self.hash == other.hash
  end
end

output = `mvn dependency:list -DincludeGroupIds=com.theplatform`

artifacts = []

read_dependencies = false
output.each_line do |line|
  if read_dependencies
    if line.index("[INFO]    ") && !line.index("[INFO]    none")
      artifacts << Artifact.new(line.strip[10..-1])
    end
    read_dependencies = !line.index("[INFO] ------------------------------------------------------------------------")
  else
    read_dependencies = line.index("[INFO] [dependency:list]")
  end
end

artifacts.uniq.each do |artifact|
  artifact.redeploy_to "scp://cim-trac.comcastonline.com/opt/csw/apache2/share/htdocs/http/godzilla/maven/repo/snapshots", "comcast-snapshot-repo"
end
