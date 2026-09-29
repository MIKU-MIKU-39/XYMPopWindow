# Xuyiming: Add source/resource references without replacing project settings.
require 'xcodeproj'

root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'Example/XYMPopWindowExample.xcodeproj'))
app = project.targets.find { |t| t.name == 'XYMPopWindowExample' }
tests = project.targets.find { |t| t.name == 'XYMPopWindowTests' }
abort 'Expected example and test targets' unless app && tests
[[app, 'XYMPopWindowExample', 'Example/XYMPopWindowExample'], [tests, 'Tests', 'Tests']].each do |target, group_name, directory|
  group = project.main_group.groups.find { |g| g.display_name == group_name }
  abort "Missing group: #{group_name}" unless group
  Dir[File.join(root, directory, '*')].sort.each do |path|
    next unless File.file?(path)
    name = File.basename(path)
    ref = group.files.find { |f| f.path == name } || group.new_file(name)
    phase = case File.extname(path)
            when '.m' then target.source_build_phase
            when '.xib', '.html' then target.resources_build_phase
            end
    phase.add_file_reference(ref) if phase && !phase.files_references.include?(ref)
  end
end
project.save
puts 'Example source and resource references synchronized.'
