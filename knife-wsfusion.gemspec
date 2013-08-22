Gem::Specification.new do |s|
    s.name = "knife-wsfusion"
    s.version = "0.1.1"
    s.summary = "VMware Workstation/Fusion support for Knife"

    s.required_rubygems_version = \
        Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=

    s.author = "Christian Hammond"
    s.description = "VMware Workstation/Fusion support for Chef's Knife command."
    s.email = "chipx86@chipx86.com"
    s.files = Dir["lib/**/*"]
    s.rubygems_version = "1.6.2"
    s.homepage = "https://github.com/chipx86/knife-wsfusion"

    s.add_dependency("chef", [">= 0.11.0"])
end
