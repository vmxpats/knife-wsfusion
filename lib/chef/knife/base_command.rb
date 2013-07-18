require 'open3'
require 'chef/knife'


module KnifeWsFusion
    class BaseCommand < Chef::Knife
        @@fusion_search_paths = [
            File.join('/', 'Applications', 'VMware Fusion Tech Preview.app'),
            File.join('/', 'Applications', 'VMware Fusion.app'),
        ]

        def is_fusion?
            @@fusion_search_paths.each do |path|
                if File.directory?(path)
                    return true
                end
            end

            return false
        end

        def get_vmrun_path
            if config[:vmrun_path]
                return config[:vmrun_path]
            end

            path = get_exe_from_path('vmrun')

            if path
                return path
            end

            if is_fusion?
                @@fusion_search_paths.each do |search_path|
                    vmrun_path = File.join(search_path, 'Contents', 'Library',
                                           'vmrun')

                    if File.executable?(vmrun_path)
                        return vmrun_path
                    end
                end
            end

            return nil
        end

        def get_exe_from_path(exe)
            exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
            ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
                exts.each do |ext|
                    exe_path = File.join(path, "#{exe}#{ext}")
                    return exe_path if File.executable?(exe_path)
                end
            end

            return nil
        end

        def create_vm_directory(vms_dir, vm_name)
            if is_fusion?
                vm_name += '.vmwarevm'
            end

            vm_dir = File.join(vms_dir, vm_name)
            Dir.mkdir(vm_dir, 0755)

            return vm_dir
        end

        def normalize_vmx_path(path)
            path = File.expand_path(path)

            if not File.exists?(path)
                return nil
            end

            if path.end_with?('.vmx')
                return path
            end

            if not File.directory?(path)
                # Well, it had better be a VMX file then.
                return path
            end

            Dir.foreach(path) do |filename|
                if filename.end_with?('.vmx')
                    return File.join(path, filename)
                end
            end

            return nil
        end

        def run_vmrun(args)
            vmrun_path = get_vmrun_path()
            cmd = [vmrun_path] + args
            out = nil
            err = nil
            exit_status = nil

            Chef::Log.debug("Running #{cmd.join(' ')}")

            Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thr|
                wait_thr.join()

                out = stdout.read()
                err = stderr.read()

                exit_status = wait_thr.value
            end

            Chef::Log.debug("... stdout: {#{out}}")
            Chef::Log.debug("... stderr: {#{err}}")
            Chef::Log.debug("... exit code: {#{exit_status}}")

            return exit_status, out, err
        end

        def set_vmx_variable(vmx_path, key, value)
            lines = []

            File.open(vmx_path, 'r') do |file|
                lines = file.readlines()
            end

            line_re = Regexp.new("^#{key}\s*=")

            File.open(vmx_path, 'w') do |file|
                lines.each do |line|
                    if line_re.match(line)
                        file.write("#{key} = \"#{value}\"\n")
                    else
                        file.write(line)
                    end
                end
            end
        end

        def clone_vm(src_vmx_path, dest_vmx_path, clone_type, clone_name,
                     snapshot_name=nil)
            args = [
                'clone',
                src_vmx_path,
                dest_vmx_path,
                clone_type,
                #"-cloneName=#{clone_name}",
            ]

            if snapshot_name
                args.push("-snapshot=#{snapshot_name}")
            end

            exit_status, out, err = run_vmrun(args)

            return exit_status == 0
        end

        def wait_for_ssh(ip_address, port)
            tcp_socket = TCPSocket.new(ip_address, port)
            readable = IO.select([tcp_socket], nil, nil, 5)

            if readable
                Chef::Log.debug("Connected to sshd on #{ip_address}")
                yield
                return true
            else
                return false
            end
        rescue Errno::ETIMEDOUT, Errno::EPERM
            return false
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH
            sleep 2
            return false
        ensure
            tcp_socket && tcp_socket.close
        end

        def power_on_vm(vmx_path)
            exit_status, out, err = run_vmrun(['start', vmx_path, 'nogui'])

            return exit_status == 0
        end

        def get_tools_state(vmx_path)
            exit_status, out, err = run_vmrun(['checkToolsState', vmx_path])

            return out.strip()
        end

        def get_guest_ip_address(vmx_path)
            exit_status, out, err = \
                run_vmrun(['getGuestIPAddress', vmx_path, '-wait'])

            if exit_status == 0
                return out.strip()
            else
                return ''
            end
        end

        def locate_config_value(key)
            key = key.to_sym
            return Chef::Config[:knife][key] || config[key]
        end
    end
end
