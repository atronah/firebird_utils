# -*- coding: utf-8 -*-
import sys
import os
import re
import argparse
import configparser



def simpeHandler(inputFile, args):
    return inputFile.read()


def escapeProcedure(inputFile, args):
    content = inputFile.read()
    if re.match(r'\s*create or alter procedure', content):
        return 'SET TERT ^ ;\n' + content + '\nSET TERT ; ^\n'
    return


def connectInfoHadler(inputFile, args):
    content = ''
    if args.logs_db:
        content = inputFile.read()
        content.replace('<logs_connect_string>', "'{logs_connect_string}'".format(args.logs_db))
        content.replace('<logs_user>', "'{logs_user}'".format(args.logs_user))
        content.replace('<logs_password>', "'{logs_password}'".format(args.logs_pwd))
        content.replace('<logs_role>', "'{}'".format(args.logs_role) if args.logs_role is not None else 'CURRENT_ROLE')
        content.replace('<gz_hub_grpid>', "{}".format(args.gz_grpid))
        content.replace('<gz_hub_uri>', "'{}'".format(args.gz_uri))
    return content





# def main():
#     parser = argparse.ArgumentParser(description='concatenates all scripts in one')
#     parser.add_argument('-t', '--tables', dest='addTables', action='store_true')
#     parser.add_argument('--logs-db', dest='logs_db', default=None, help='connection string for logs database')
#     parser.add_argument('--logs-user', dest='logs_user', default='CHEA', help='user for connect to logs database')
#     parser.add_argument('--logs-pwd', dest='logs_pwd', default='PDNTP', help='password for connect to logs database')
#     parser.add_argument('--logs-role', dest='logs_role', default=None, help='role for connect to logs database')
#     parser.add_argument('--gz-grpid', dest='gz_grpid', default='98'
#                         , help='grpid (database group identifier) for remote exchange service')
#     parser.add_argument('-gz-uri', dest='gz_uri', default='http://10.128.66.112/Service/HubService.svc'
#                         , help='uri for remote exchange service')
#     args = parser.parse_args()
#
#     processQueue = []
#     if args.addTables:
#         processQueue.append(('tables', simpeHandler))
#     if args.logs_db:
#         processQueue.append(('connectInfo', connectInfoHadler))
#     processQueue.append(('procedures', simpeHandler))
#
#
#     src = '.'
#     commonOutName = 'commonOut.sql'
#     with open(commonOutName, 'w', encoding='utf-8') as o:
#         for scriptListName, handler in processQueue:
#             for fName in scripts.get(scriptListName, []):
#                 with open(os.path.join(src, fName), 'r', encoding='utf-8') as script:
#                     o.write(handler(script, args) + '\n')

def scriptsContent(settings, group):
    if settings.has_option(group, 'scripts'):
        for fname in settings[group]['scripts'].split('\n'):
            fname = fname.strip('"')
            if os.path.isfile(fname):
                with open(fname, 'r', encoding=settings['general']['encoding']) as f:
                    content = f.read()
                    try:
                        content = content.format(**settings[group])
                        yield content
                    except Exception as e:
                        print('error "{0}" occured during formating content of file: "{1}"'.format(e, fname))



def main():
    parser = argparse.ArgumentParser(description='concatenates all scripts in one')
    parser.add_argument('-d', '--dir', dest='dir', default=None, help='directory with scripts')
    parser.add_argument('-o', '--out', dest='out', default=None, help='result file name')
    parser.add_argument('-s', '--settings', dest='settings', default='settings.ini', help='settings file')
    parser.add_argument('-g', '--groups', dest='groups', default='groups'
                        , help='option name which contains name of groups with used scripts')
    args = parser.parse_args()

    if args.dir:
        os.chdir(args.dir)

    settings = configparser.ConfigParser(defaults={'encoding': 'utf-8'})
    settings.read(args.settings)

    if not settings.has_option('general', args.groups):
        return 1

    # print(settings['routines'])
    if args.out is None:
        args.out = args.groups + '.sql'

    with open(args.out, 'w', encoding='utf-8') as o:
        for group in settings['general'][args.groups].split(','):
            group = group.strip()
            for content in scriptsContent(settings, group):
                o.write(content + '\n\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
