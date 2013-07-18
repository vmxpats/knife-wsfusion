require 'chef/knife'
require 'chef/knife/base_command'


module KnifeWsFusion
    class WsfusionCreate < BaseCommand
        deps do
            require 'chef/json_compat'
            require 'chef/knife/bootstrap'
            Chef::Knife::Bootstrap.load_deps
        end

        banner "knife wsfusion create (options)"

        option :bootstrap_version,
            :long => '--bootstrap-version VERSION',
            :description => 'The version of Chef to install',
            :proc => Proc.new { |v| Chef::Config[:knife][:bootstrap_version] = v }

        option :use_chef_solo,
            :long => "--chef-solo",
            :description => "Use Chef Solo instead of Chef Server",
            :default => false,
            :proc => Proc.new { |mode| Chef::Config[:knife][:chef_mode] = mode }

        option :chef_node_name,
            :short => "-N NAME",
            :long => "--node-name NAME",
            :description => "The Chef node name for your new node",
            :proc => Proc.new { |key| Chef::Config[:knife][:chef_node_name] = key }

        option :clone_snapshot_name,
            :long => '--clone-snapshot-name NAME',
            :description => 'The name of the snapshot from the template to ' \
                            'clone'

        option :clone_type,
            :long => '--clone-type [full|linked]',
            :description => 'The type of clone to make (full or linked)',
            :default => 'linked'

        option :distro,
            :short => "-d DISTRO",
            :long => "--distro DISTRO",
            :description => "Bootstrap a distro using a template; default is " \
                            "'chef-full'",
            :proc => Proc.new { |d| Chef::Config[:knife][:distro] = d }

        option :identity_file,
            :short => "-i IDENTITY_FILE",
            :long => "--identity-file IDENTITY_FILE",
            :description => "The SSH identity file used for authentication"

        option :json_attributes,
            :short => "-j JSON",
            :long => "--json-attributes JSON",
            :description => "A JSON string to be added to the first run of " \
                            "chef-client",
            :proc => lambda { |o| JSON.parse(o) }

        option :run_list,
            :short => "-r RUN_LIST",
            :long => "--run-list RUN_LIST",
            :description => "Comma-separated list of roles/recipes to apply",
            :proc => lambda { |o| o.split(/[\s,]+/) }

        option :ssh_password,
            :short => "-P PASSWORD",
            :long => "--ssh-password PASSWORD",
            :description => "The ssh password"

        option :ssh_port,
            :short => "-p PORT",
            :long => "--ssh-port PORT",
            :description => "The ssh port",
            :default => "22",
            :proc => Proc.new { |key| Chef::Config[:knife][:ssh_port] = key }

        option :ssh_user,
            :short => "-x USERNAME",
            :long => "--ssh-user USERNAME",
            :description => "The ssh username",
            :default => "root"

        option :template_file,
            :long => "--template-file TEMPLATE",
            :description => "Full path to the location of the template to use",
            :proc => Proc.new { |t| Chef::Config[:knife][:template_file] = t },
            :default => false

        option :vm_source_path,
            :long => '--vm-source-path PATH',
            :description => 'Path to the VM used for cloning',
            :required => true

        option :vm_name,
            :long => '--vm-name NAME',
            :description => 'Name of the new VM',
            :required => true

        option :vmrun_path,
            :long => '--vmrun-path PATH',
            :description => 'Custom path to vmrun'

        attr_accessor :initial_sleep_delay

        def run
            vm_source_path = config[:vm_source_path]
            src_vmx_path = normalize_vmx_path(vm_source_path)

            if not src_vmx_path
                ui.fatal("No VM was found at #{vm_source_path}")
                exit 1
            end

            vms_dir = File.dirname(File.dirname(src_vmx_path))

            dest_vm_name = config[:vm_name]
            dest_vm_dir = create_vm_directory(vms_dir, dest_vm_name)

            if not dest_vm_dir
                ui.fatal('Unable to find a place to create the new VM')
                exit 1
            end

            # Check for Tools in the source VM.
            tools_state = get_tools_state(src_vmx_path)

            if tools_state != 'installed' and tools_state != 'running'
                ui.fatal("The source VM doesn't appear to have " +
                         "VMware Tools installed")
                exit 1
            end

            dest_vmx_path = File.join(dest_vm_dir, "#{dest_vm_name}.vmx")

            # Create the virtual machine by cloning the existing one.
            puts "Creating VM #{dest_vm_name} from #{vm_source_path}..."

            success = clone_vm(src_vmx_path, dest_vmx_path, config[:clone_type],
                               dest_vm_name, config[:clone_snapshot_name])

            if not success
                ui.fatal("Unable to clone the VM. See the log for details.")
                exit 1
            end

            # Now power on the VM.
            puts "Powering on the new VM..."
            if not power_on_vm(dest_vmx_path)
                ui.fatal("Unable to power on the VM. See the log for details.")
                exit 1
            end

            # Wait for the guest's IP address.
            puts "Waiting for an IP address from the guest..."
            ip_address = get_guest_ip_address(dest_vmx_path)

            # Wait for SSH access.
            puts "Waiting for sshd..."
            print ('.') until wait_for_ssh(ip_address, config[:ssh_port]) do
                sleep @initial_sleep_delay ||= 10;
                print 'done'
            end

            if Chef::Config[:knife][:chef_mode] != "solo"
                puts "Bootstrapping VM"
                bootstrap_for_node(dest_vm_name, ip_address).run()
            end
        end

        def bootstrap_for_node(vm_name, ip_address)
            knife_config = Chef::Config[:knife]

            bootstrap = Chef::Knife::Bootstrap.new
            bootstrap.name_args = [ip_address]
            bootstrap.config[:run_list] = config[:run_list]
            bootstrap.config[:chef_node_name] = \
                config[:chef_node_name] || vm_name
            bootstrap.config[:first_boot_attributes] = \
                config[:json_attributes] || {}
            bootstrap.config[:bootstrap_version] = \
                locate_config_value(:bootstrap_version)
            bootstrap.config[:distro] = locate_config_value(:distro)
            bootstrap.config[:template_file] = \
                locate_config_value(:template_file)
            bootstrap.config[:environment] = locate_config_value(:environment)
            bootstrap.config[:ssh_user] = config[:ssh_user]
            bootstrap.config[:ssh_password] = config[:ssh_password]
            bootstrap.config[:use_sudo] = (config[:ssh_user] != 'root')
            bootstrap.config[:identity_file] = config[:identity_file]
            bootstrap.config[:no_host_key_verify] = \
                locate_config_value(:no_host_key_verify)
            bootstrap.config[:encrypted_data_bag_secret] = \
                locate_config_value(:encrypted_data_bag_secret)
            bootstrap.config[:encrypted_data_bag_secret_file] = \
                locate_config_value(:encrypted_data_bag_secret_file)

            return bootstrap
        end
    end
end
