#!/opt/puppetlabs/puppet/bin/ruby

require "optparse"
require "fileutils"

opt = OptionParser.new
opt.banner = "Store Facts in a YAML file for MCollective"
opt.separator ""

opt.on("--out FILE", "-o", "Path to facts") do |v|
  @outfile = v
end

opt.on("--pid FILE", "-p", "Path to pidfile") do |v|
  @pid = v
end

opt.parse!

abort("Please specify a file to write to") unless @outfile

if @pid
  begin
    lock = File.open(@pid, File::CREAT | File::EXCL | File::WRONLY)

    at_exit do
      begin
        lock.close
      ensure
        File.delete(@pid)
      end
    end

    lock.write($$)
  rescue
    abort("Failed to obtain lock for %s using '%s', the refresher may already be running: %s: %s" % [$0, @pid, $!.class, $!.to_s])
  end
end

require "rubygems"

if Gem.win_platform?
  $: << "C:/Program Files/Puppet Labs/Puppet/facter/lib"
end

require "yaml"
require "puppet"
require "facter"
require "tempfile"

# this was copied from cfactor lib/src/ruby/ruby.cc load_puppet
Puppet.initialize_settings

unless $LOAD_PATH.include?(Puppet[:libdir])
  $LOAD_PATH.push(Puppet[:libdir])
end

Facter.reset
Facter.search_external([Puppet[:pluginfactdest]])
Puppet.initialize_facts

file = Tempfile.new("facter_yaml_writer")
file.write(Facter.to_hash.to_yaml)
file.close

FileUtils.mv(file.path, @outfile)
