#import the xcodeproj ruby gem
require 'xcodeproj'
#define the path to your .xcodeproj file
project_path = 'MSAL/MSAL.xcodeproj'
#open the xcode project
project = Xcodeproj::Project.open(project_path)
#find the group on which you want to add the file
group = project.main_group['test/automation']
#get the file reference for the file to add
file = group.new_file('conf.json')
#add the file reference to the projects first target
project.targets.each do |target|
    if target.name == "MultiAppiOSTests" || target.name == "InteractiveiOSTests"
        target.add_resources([file])
    end
end
#finally, save the project
project.save