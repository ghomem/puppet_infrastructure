Puppet::Type.newtype(:zimbra_user) do

    require 'puppet/property/boolean'

    desc "Type to manage Zimbra users"

    ensurable

    newproperty(:aliases, :array_matching => :all) do
        desc "Mailbox aliases"
        validate do |value|
            value.each do |val|
                fail("Aliases must be fully qualified") unless val =~ /.*@.*/
            end
        end
        munge do |value|
            value
        end
    end

    newproperty(:mailbox_size) do
        desc "The size of the mailbox"
        validate do |value|
            fail("Invalid mailbox size, it should contain a number and a unit M|G") unless value =~ /\d+(M|G){1}/
        end
        munge do |value|
            if value.include? 'G'
                (value.chomp('G').to_i * 1024 * 1024 * 1024).to_s
            elsif value.include? 'M'
                (value.chomp('M').to_i * 1024 * 1024).to_s
            end
        end
    end

    # we are using a string instead of a boolean
    # because the workflow with booleans was broken
    # we could not figure out in useful time a fix
    newproperty(:is_admin) do
        desc "User will be administrator"
    end

    newparam(:domain) do
        desc "Account domain"
    end

    newparam(:location) do
        desc "mailbox location in the cluster"
    end

    # For puppet to query and enforce the state of the user_name (aka displayName aka Common Name)
    # we need to change it from a parameter to a property
    newproperty(:user_name) do
        desc "username"
    end

    newparam(:mailbox) do
        desc 'Mailbox'
    end
    newparam(:emailaddress, :namevar => true) do
        desc 'Email Address'
    end

    # For puppet to query and enforce the state of the password hash (aka pwd aka userPassword)
    # we need to change it from a parameter to a property
    newproperty(:pwd) do
        desc 'Mailbox password'
        validate do |value|
            # at least one character must be found in the password hash
            fail("Password hash empty") unless value =~ /^.{1,}$/
        end
    end

    validate do
        raise Puppet::Error, "Must specify domain parameter" unless
        @parameters.include?(:domain)
    end

end
