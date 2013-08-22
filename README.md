Chef Knife plugin for Workstation/Fusion
========================================

Chef is a fantastic system for maintaining server configurations, but it had
one fatal flaw... It didn't work seamlessly with
[VMware Workstation](http://www.vmware.com/products/workstation) or
[Fusion](http://www.vmware.com/products/fusion/overview.html)!
The humanity! This had to be fixed.


Your life is about to improve
-----------------------------

It is.

This plugin, once installed, will let you test your deployments against a
Workstation/Fusion VM, which it will happily create for you, based on a
template VM you provide.

It works with Chef Server, so install that or sign up for
[Hosted Chef](http://www.opscode.com/enterprise-chef/) (it's free for up to 5
nodes!).

You'll need a modern Chef. This is tested with Chef 11.4.4. So, something like
that, or newer.

You will need the very latest major version of Workstation > 9.0, or Fusion >
5.0. As of August 21, 2013, these are Tech Preview versions. You'll want
to download the
[Workstation Tech Preview](https://communities.vmware.com/community/vmtn/beta/workstation_2013) or
[Fusion Tech Preview](https://communities.vmware.com/community/vmtn/beta/fusion_2013).


Getting your template VM ready
------------------------------

You will need to create a VM that you will use as a base for your server.  A
good, freshly installed Linux VM (say, Ubuntu Server, or CentOS) is your best
bet. You'll need the following on it:

  1. A user with sudo permissions to log into.
  2. SSH access enabled.
  3. VMware Tools installed.
  4. A Chef Knife bootstrap template file that's compatible.

That's it. Power it off once it's set up, and don't touch it again. It's a
template now.

All set up? Good, let's begin playing with knives.


Installing knife-wsfusion
-------------------------

To install knife-wsfusion, run:

    $ gem install knife-wsfusion

You may have to put ```sudo``` in front of that, depending on your setup.

Verify that worked with:

    $ knife --help | grep wsfusion

You should see ```knife wsfusion create```. I'm going to assume that worked.


Creating your first deployment
------------------------------

At this point, you should have your template VM set up with a login and
password that has sudo permissions. For the examples below, I'm assuming the
following:

  1. Your VM is at ```$HOME/VMs/CentOS-Template/```
  2. Your username is ```vmwarevm```.
  3. Your password is also ```vmwarevm```. (Please use something more secure in
	 practice.)
  4. Your new VM name is going to be called "Wordpress." (This will be created
	 for you.)
  5. You have a Chef Knife bootstrap template file for the OS you're installing
	 into. Chef provides a few samples. This is basically what you use to get
	 all the right stuff installed into a new VM.
  5. You have an account on Hosted Chef, and your configuration is all set up.
  6. You have a deployment with a runlist all set up. I'm going to use
	 ```recipe[wordpress]``` as the sample runlist.

Okay, good. Let's kick this pig.

    $ knife wsfusion create \
	    --vm-name=Wordpress \
		--vm-source-path=$HOME/VMs/CentOS-Template \
		--ssh-user=vmwarevm \
		--ssh-password=vmwarevm \
		--template-file=/path/to/centos.erb \
		--run-list="recipe[wordpress]"

That should run for a while, with lots of standard Chef output. Hopefully
without any errors (if there are any, it's probably your fault).

It may ask for a password at some point. This would be the same password as
above. It's just sudo asking to type it in.

At the end, your brand new Wordpress VM should be powered on and accessible via
a web browser. The IP address for it should be in your console output from the
knife command (actually, it should prefix every line of output).

Awesome, yes?


I'm lazy, give me a test repository
-----------------------------------

No problem. I built a
[demo repository](https://github.com/chipx86/knife-wsfusion-wordpress-demo)
JUST FOR YOU.

Follow the instructions there.


Eep! It all went horribly wrong!!!
----------------------------------

If you're reading this, and the subject accurately reflects your mental state
after my instructions, then somehow, your setup and my setup are not 100%
exactly the same.

Most problems are going to fall into one of these categories:

  1. The VM or the Knife bootstrap template file isn't set up correctly.
  2. The template VM was already running.
  3. The Chef Server configuration isn't quite correct.
  4. The version of Workstation/Fusion isn't correct.
  5. Your computer is having a meltdown.
  6. Something else is going horribly wrong.
  7. knife-wsfusion has a bug.

I tried to sort that in the order from most realistic to least.

I'm happy to help sort through problems (particularly if it seems that
knife-wsfusion is buggy), but I will admit, I'm not the biggest Chef expert
around, and Chef isn't always super obvious at first, so I won't always be able
to give a lot of help.

I'd recommend trying the test repository above first and making sure that
works first.
