#!/usr/bin/python3

# url
# localhost:9200/_search

import json, sys, argparse
from urllib import request

# START CONSTANTS
EXIT_OK = 0
EXIT_WARNING = 1
EXIT_CRITICAL = 2
EXIT_UNKOWN = 3

PRINT_OK = 'OK'
PRINT_WARNING = 'Warning'
PRINT_CRITICAL = 'Critical'
PRINT_UNKOWN = 'Unknown'

HEADERS = {'Content-Type': 'application/json'}

DEFAULT_START_DATE = 'now-1M'
DEFAULT_END_DATE = 'now'
# END CONSTANTS

# START FUNCTION DEFINITION

# function to print if --verbose
# was given to the script
def verb_print(verbose : bool, info : str) -> None:
    if verbose:
        print(info)

def sshd_nagios_check(data):
    if data['hits']['total'] > 0:
        print(PRINT_CRITICAL)
        ordered_result = []
        for element in data['hits']['hits']:
            host = element['_source']['syslog_hostname']
            sl_timestamp = element['_source']['syslog_timestamp']
            username = element['_source']['syslog_message'].split()[-3]
            ordered_result.append([sl_timestamp, username, host])
        ordered_result.sort(key=lambda item: item[0])
        for res in ordered_result:
            log_line = '%s - %s - %s' % (res[0], res[1], res[2])
            print(log_line)
        exit(EXIT_CRITICAL)
    else:
        print(PRINT_OK)
        exit(EXIT_OK)

# this constant stores the function pointers in a dict to
# compact the code that calls the functions from the CLI
# the dict key should be the string given to -f | --function in the command line
FUNCTIONS = { 'sshd': sshd_nagios_check }

# we convert here the dic keys object to
# a list to be compatible with
# argparse add_argument choices parameter
FUNCTIONS_KEY_LIST = [k for k in FUNCTIONS.keys()]

# END FUNCTION DEFINITION

# argparse setup
parser = argparse.ArgumentParser(description='CLI to fetch Elastic Search logs and present results compatible with Nagios checks')

# this is just a "passive" argument that serves for template
# if in the future we want to add some other functions
parser.add_argument('-f', '--function', type = str, choices = FUNCTIONS_KEY_LIST, help = 'Function that will parse the Elastic API Answer', default = 'sshd', required = False)

# offset variable and start/end should be mutually exclusive
parser.add_argument('--offset', type = str, required = False, help = 'How far back do you want to check? Ex: now-1M represents "In the last month"')

# start of sample set
parser.add_argument('-s', '--start_date', type = str, required = False, help = 'What date you want the check set to start. (should be older than --end_date)')

# end of sample set
parser.add_argument('-e', '--end_date', type = str, required = False, help = 'What date you want the check set to end. (should be newer than --start_date)')

parser.add_argument('-q', '--query', type = str, required = True, help = 'Raw query that would be put in Kibana')

parser.add_argument('--verbose', required = False, default = False, help = 'Print extra info to the standard output (do not use if running as nagios plugin)', action='store_true')

parser.add_argument('--sample_size', type = int, required = False, help = 'How many results you want to read?', default = 10)

args = parser.parse_args()

# a few extra checks than what argparse provides above are needed
# for this to make sense from a semantic standpoint
if args.offset and args.start_date or args.offset and args.end_date:
    parser.error('The --offset argument can\'t be used in along with --end_date or --start_date')

if args.start_date and not args.end_date or not args.start_date and args.end_date:
    parser.error('Please specify both --start_date and --end_date')

# if no date parameter was specified we use the internal defaults
if not args.offset and not args.start_date and not args.end_date:
    START_DATE = DEFAULT_START_DATE
    END_DATE = DEFAULT_END_DATE
    local_info_str = 'No limit dates or offset were specified, using %s as offset' % (DEFAULT_START_DATE)
    verb_print(args.verbose, local_info_str)
# if offset is defined
elif args.offset and not args.start_date and not args.end_date:
    START_DATE = args.offset
    END_DATE = DEFAULT_END_DATE
    local_info_str = 'Using specified offset: %s' % (START_DATE)
    verb_print(args.verbose, local_info_str)
# if both start and end are defined
elif args.start_date and args.end_date:
    START_DATE = args.start_date
    END_DATE = args.end_date
    local_info_str = 'Using specified dates: START - %s | END - %s' % (START_DATE, END_DATE)
    verb_print(args.verbose, local_info_str)

# this path is hardcoded on purpose, until a better
# way of setting the filename comes to mind
FULL_QUERY = '{ "query": {"bool": {"must": [{"query_string": {"query": "%s", "analyze_wildcard": true, "default_field": "*"} }, {"range": {"received_at": {"gte": "%s","lte": "%s"} } }] } } }' % (args.query, START_DATE, END_DATE)
URL = 'http://localhost:9200/_search?size=%s' % (str(args.sample_size))

# main logic
QUERY_JSON = json.loads(FULL_QUERY)
request_data = json.dumps(QUERY_JSON).encode('utf-8')
#print(json.dumps(QUERY_JSON, indent=2))

try:
    my_request = request.Request(URL, data = request_data, headers = HEADERS)
    response = request.urlopen(my_request)
    data = response.read().decode('utf-8')
    usable_data = json.loads(data)
    # answer treatment with function -f | --function
    FUNCTIONS[args.function](usable_data)
except Exception as e:
    print(PRINT_UNKOWN)
    print(e)
    exit(EXIT_UNKOWN)
