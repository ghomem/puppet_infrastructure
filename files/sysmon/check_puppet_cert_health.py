#!/usr/bin/python3

import os
import sys
import subprocess
import yaml
from datetime import datetime

def main():

    healthcheck_command = ["puppet", "certregen", "healthcheck", "--all",  "--render-as", "yaml"]
    if os.geteuid() == 0:
        # This runs the command and collects the output
        try:
            output = subprocess.check_output(healthcheck_command)
        except Exception:
            print ("command '%s' failed" % " ".join(healthcheck_command))
            sys.exit(1)
    else:
        print("please run as root")
        sys.exit(1)

    #This will be the list where we will store the dictionaries containing the information about each machine's health
    list_of_dicts = yaml.safe_load(output)
    expiring_machine = {}
    earliest_expiration_date = datetime.max

    # Here we will check the status of each machine and report the result in Nagios format
    for element in list_of_dicts:
        if (element[':expiry'][':status'] == ':expired'):
            print("Critical: certificate of %s has expired on %s." % (element[':name'], element[':expiry'][':expiration_date']))
            sys.exit(2)
        if (element[':expiry'][':expiration_date'] < earliest_expiration_date):
            earliest_expiration_date = element[':expiry'][':expiration_date']
            expiring_machine = element

    expiring_machine_name = expiring_machine[':name'].strip()
    expiring_time = expiring_machine[':expiry'][':expires_in'].strip()

    if (abs((datetime.now() - earliest_expiration_date).days) < 10):
        print ("Critical: certificate of %s will expire in %s" % (expiring_machine_name, expiring_time))
        sys.exit(2)
    elif (abs((datetime.now() - earliest_expiration_date).days) < 30):
        print ("Warning: Certificate of %s will expire in %s" % (expiring_machine_name, expiring_time))
        sys.exit(1)
    else:
        print ("OK: The next certificate expiration will be from %s, in %s" % (expiring_machine_name, expiring_time))
        sys.exit(0)


if __name__ == "__main__":
    main()
