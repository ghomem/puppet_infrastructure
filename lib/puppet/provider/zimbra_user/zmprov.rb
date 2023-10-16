Puppet::Type.type(:zimbra_user).provide(:zmprov) do

    # We need this module to decode/encode password hashes
    require "base64"
    require 'puppet/property/boolean'

    desc "Manage users for Zimbra Collaboration Suite"

    confine :operatingsystem => [:Ubuntu,:Debian,:CentOS]
    confine :true => begin
        File.exists?('/opt/zimbra/bin/zmprov') && File.exists?('/opt/zimbra/common/bin/ldapsearch')
    end
    defaultfor :operatingsystem => [:Ubuntu,:CentOS]

    commands :zmprov => '/opt/zimbra/bin/zmprov',
             :zmmailbox => '/opt/zimbra/bin/zmmailbox',
             :ldapsearch => '/opt/zimbra/common/bin/ldapsearch',
             :zmlocalconfig => '/opt/zimbra/bin/zmlocalconfig'

    require 'socket'
    @host_name=Socket.gethostbyname(Socket.gethostname.to_s)[0]

#    mk_resource_methods

    def self.instances

        # Getting ldap password
        ldap_pass = zmlocalconfig('-s','zimbra_ldap_password').gsub('zimbra_ldap_password = ','').chomp("\n")

        # Configuring ldap filter for users with zimbraMailDeliveryAddress
        ufilter = "(&(objectClass=inetOrgPerson)(objectClass=zimbraAccount)(zimbraMailDeliveryAddress=*))"

        # here we get all users
        raw = ldapsearch('-LLL','-H',"ldap://#{@host_name}:389",'-D','uid=zimbra,cn=admins,cn=zimbra','-x','-w',ldap_pass,ufilter)

        # zimbraCOS
        cos_filter='objectClass=zimbraCOS'
        quotas=Hash.new
        raw_COS = ldapsearch('-LLL','-H',"ldap://#{@host_name}:389",'-D','uid=zimbra,cn=admins,cn=zimbra','-x','-w',ldap_pass,cos_filter).split("\n\n")
        raw_COS.each do |v|
            if v.include?('dn: cn=default,cn=cos,cn=zimbra')
                cos_id="default"
            else
                # we should not use \n in the regex for grep as we've discarded that in the previous split, and
                # we need to get an element of the result of using grep, so that we no longer have an array
                cos_id= v.split("\n").grep(/zimbraId: .*/)[0].to_s.gsub('zimbraId: ','').chomp

            end
            # we need to get an element of the result of using grep, so that we no longer have an array
            quota= v.split("\n").grep(/zimbraMailQuota: .*/)[0].to_s.gsub('zimbraMailQuota: ','').chomp
            quotas[cos_id]=quota
        end
        #############

        raw_users=raw.split("\n\n")
        raw_users.compact.map  { |i| 
            # getting zimbraMailDeliveryAddress
            name = i.split("\n").grep(/zimbraMailDeliveryAddress: /)[0].gsub('zimbraMailDeliveryAddress: ','').chomp

            # getting displayName
            if i.include?('displayName: ')
                displayName = i.split("\n").grep(/displayName: /)[0].gsub('displayName: ','').chomp
            else
                displayName = String.new
            end
            # getting aliases for each user
            raw_aliases=i.split("\n").grep(/zimbraMailAlias: /)
            unless raw_aliases.empty?
                aliases= raw_aliases.collect { |x| x.gsub('zimbraMailAlias: ','').gsub("\n",'')}
            else
                aliases= Array.new
            end

            # getting mailBox quota

            if i.split("\n").grep(/zimbraMailQuota: /).empty? and i.split("\n").grep(/zimbraCOSId: /).empty?
                quota = quotas['default']
            elsif  i.split("\n").grep(/zimbraMailQuota: /).any?
                quota = i.split("\n").grep(/zimbraMailQuota: /)[0].to_s.gsub('zimbraMailQuota: ','').chomp
            # grep method is not availalbe for strings, so before we use it we need to split the string into an array
            elsif i.split("\n").grep(/zimbraCOSId: /).any?
                # we need to get an element of the result of using grep, so that we no longer have an array
                zimbraid = i.split("\n").grep(/zimbraCOSId: /)[0].to_s.gsub('zimbraCOSId: ','').chomp
                quota=quotas[zimbraid]
            end

            # getting the password hash (aka userPassword aka pwd)
            if i.include?('userPassword:: ')
                # this case is a bit trickier than the previous
                # mainly because the password hash is a multiline string
                # and we don't know how many lines beforehand
                # and on top of that it is a base64 encoding
                # possibly with the {crypt} prefix
                # So we roll-out a somewhat less trivial regex for this using some capturing and non-capturing groups.
                # The first capturing group is easy to setup because we know it starts with userPassword
                # and it ends with a newline (optional, because it is not there if the password field is the last one), so we use
                # userPassword::\ (.*)\n?
                # Now, each of the (possibly) following lines for the hash MUST start with a space and MUST end with a newline
                # that would be
                #      \ .*\n
                # but we can have zero-or-many lines, so we have to repeat that pattern
                #     (\ .*\n)*
                # and we want to capture the repetition so we add a capture group to that
                #    ((\ .*\n)*)
                # but then we don't care about the inside groups, so we discard those with the prefix
                # ((?> \ .*\n)*)
                # and for the very last of these lines the trailing newline may not be there so we make it optional
                # ((?> \ .*\n?)*)
                # putting it together and getting rid of spaces and newlines:
                captured = i.match(/userPassword::\ (.*)\n?((?>\ .*\n?)*)/).captures.join().gsub("\n",'').gsub(' ','')
                # now we convert from base64
                decoded = Base64.decode64(captured)
                # we put {crypt} as a prefix to hashes, so let's take that away if it's present
                userPassword = decoded.gsub(/^(\{crypt\})?/,'')
            else
                userPassword = String.new
            end

            if i.include?('zimbraIsAdminAccount: ')
                cur_value = i.split("\n").grep(/zimbraIsAdminAccount:/)[0].split()[1]

                #Puppet.info("parameter has value '#{cur_value}'")

                if cur_value == 'TRUE'
                    is_admin = 'true'
                else
                    is_admin = 'false'
                end
            else
                is_admin = 'false'
            end

            #Puppet.info("IS_ADMIN has value '#{is_admin}'")

            new(:name => name, 
                :ensure => :present, 
                :user_name => displayName, 
                :aliases => aliases,
                :mailbox_size => quota,
                :pwd => userPassword,
                :is_admin => is_admin)
        }
    end

    def self.prefetch(resources)
        users = instances
        resources.keys.each do |name|
            if provider = users.find{ |usr| usr.name == name }
                resources[name].provider = provider
            end
        end
    end

    def exists?
        @property_hash[:ensure] == :present
	end

    def create
        # Create user mailbox
        #
        #
        options= Array.new
        (options << 'zimbraMailHost' << resource[:location]) if resource[:location]
        (options << 'zimbraMailQuota' << resource[:mailbox_size]) if resource[:mailbox_size]
        (options << 'displayName' <<  resource[:user_name]) if resource[:user_name]

        zmprov('ca',resource[:mailbox]+'@'+resource[:domain],"ukkv0UgB3murNwuqu0MO",options)
        zmprov('ma',resource[:mailbox]+'@'+resource[:domain],"userPassword","{crypt}"+resource[:pwd])
        # Add aliases
        unless resource[:aliases].nil?
            resource[:aliases].flatten.each { |element|
                zmprov('aaa',resource[:mailbox]+'@'+resource[:domain],element)
            }
        end

        # make this user admin if is_admin is true
        if resource[:is_admin] == 'true'
            zmprov( 'ma',resource[:mailbox]+'@'+resource[:domain],'zimbraIsAdminAccount','TRUE')
        else
            zmprov( 'ma',resource[:mailbox]+'@'+resource[:domain],'zimbraIsAdminAccount','FALSE')
        end
    end

    def destroy
        zmprov('da',resource[:mailbox]+'@'+resource[:domain])
    end

    def mailbox_size
        @property_hash[:mailbox_size]
    end

    def aliases
        @property_hash[:aliases]
    end


    def mailbox_size=(value)
        zmprov('ma',resource[:mailbox]+'@'+resource[:domain], 'zimbraMailQuota', resource[:mailbox_size])
    end

    def aliases=(value)
        STDERR.puts resource[:aliases].inspect
        remove_diff = @property_hash[:aliases] - resource[:aliases].flatten

        if remove_diff.any?
            remove_diff.each { |val|
                zmprov('raa',resource[:mailbox]+'@'+resource[:domain],val)
            }
        end
        add_diff = resource[:aliases].flatten - @property_hash[:aliases]
        if add_diff.any?
            add_diff.each { |val|
                zmprov('aaa',resource[:mailbox]+'@'+resource[:domain],val)
            }
        end
    end

    # method to get user_name (aka displayName aka Common Name)
    def user_name
        @property_hash[:user_name]
    end

    # method to set user_name (aka displayName aka Common Name)
    def user_name=(value)
      # ma stands for ModifyAccount
      zmprov('ma',resource[:mailbox]+'@'+resource[:domain], 'displayName', resource[:user_name])
    end

    # method to get password hash (aka pwd aka userPassword)
    def pwd
        @property_hash[:pwd]
    end

    # method to set password hash (aka pwd aka userPassword)
    def pwd=(value)
      # ma stands for ModifyAccount
      zmprov('ma',resource[:mailbox]+'@'+resource[:domain],"userPassword","{crypt}"+resource[:pwd])
    end

    # functions to manage user admin status
    def is_admin
        current_value = @property_hash[:is_admin]
        #Puppet.info("CURRENT VALUE IS: '#{current_value}'")
        current_value
    end

    def is_admin=(value)
        #Puppet.info("SET VALUE IS: '#{value}'")
        if value == 'true'
            zmprov( 'ma',resource[:mailbox]+'@'+resource[:domain],'zimbraIsAdminAccount','TRUE')
        else
            zmprov( 'ma',resource[:mailbox]+'@'+resource[:domain],'zimbraIsAdminAccount','FALSE')
        end
    end
end
