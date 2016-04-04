# -*- coding: utf-8 -*-
import sys
import os
import re
import argparse
import configparser
import datetime
import subprocess
import shlex
import glob



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


def get_git_info(obj_path):
    git_info = {}
    
    obj_path = os.path.abspath(obj_path)
    workdir = os.path.abspath(os.path.dirname(obj_path))
    while not os.path.ismount(workdir):
        if os.path.isdir(os.path.join(workdir, '.git')):
            for param, command in {'sha': 'git rev-parse HEAD'
                                    , 'branch': 'git rev-parse --abbrev-ref HEAD'
                                    , 'author': 'git log -1 --pretty="%an (%ae)" -- "{}"'.format(obj_path)
                                    , 'date': 'git log -1 --pretty="%ad" -- "{}"'.format(obj_path)
                                    , 'message': 'git log -1 --pretty=%B -- "{}"'.format(obj_path)
                                    }.items():
                #if param == 'message': print(command)
                p = subprocess.Popen(shlex.split(command), stdout = subprocess.PIPE, cwd = workdir)
                p.wait()
                git_info[param] = ''.join([line.decode('utf-8') for line in p.stdout.readlines()]).replace('\n', ' ')
            break
        workdir = os.path.abspath(os.path.join(workdir, os.pardir))
    return git_info


def add_git_info(content, git_info):
    if not git_info:
        return content
    first_begin = re.search(r'\bbegin\b', content, re.IGNORECASE)
    if first_begin:
        return content[:first_begin.end()] + '\n' \
                    + '-- generated on ' + str(datetime.datetime.now()) + '\n' \
                    + '-- git branch: ' + git_info['branch'] + '\n' \
                    + '-- git SHA-1: ' + git_info['sha'] + '\n' \
                    + '-- git author: ' + git_info['author'] + '\n' \
                    + '-- git date: ' + git_info['date'] + '\n' \
                    + '-- git commit message: ' + git_info['message'] + '\n' \
                    + content[first_begin.end():]
    return content
    

def fileContent(fname, encoding, params):
    with open(fname, 'r', encoding=encoding) as f:
        print('processing file: {}'.format(fname))
        content = add_git_info(f.read(), get_git_info(fname))
        try:
            content = content.format(**params)
            return content
        except Exception as e:
            print('error "{0}" occured during formating content of file: "{1}"'.format(e, fname))
    

def processScriptsGroup(settings, group, encoding):
    if settings.has_option(group, 'scripts'):
        for fname in settings[group]['scripts'].split('\n'):
            fname = fname.strip('"')
            if os.path.isfile(fname):
                yield fileContent(fname, encoding, settings[group])


def main():
    encoding = 'utf-8'
    
    parser = argparse.ArgumentParser(description='concatenates all scripts in one')
    parser.add_argument('-d', '--dir', dest='dir', default=None, help='directory with scripts')
    parser.add_argument('-o', '--out', dest='out', default=None, help='result file name')
    parser.add_argument('-s', '--settings', dest='settings', default='settings.ini', help='settings file')
    parser.add_argument('-g', '--groups', dest='groups', default='groups'
                        , help='option name which contains name of groups with used scripts')
    parser.add_argument('files', nargs='*')
    args = parser.parse_args()

    if args.dir:
        os.chdir(args.dir)

    settings = configparser.ConfigParser()
    settings.read(args.settings)

    # print(settings['routines'])
    if args.out is None:
        args.out = args.groups + '.sql'
    print(os.path.abspath(args.out))
    
    with open(args.out, 'w', encoding = encoding) as o:
        if settings.has_option('general', args.groups):
            for group in settings['general'][args.groups].split(','):
                group = group.strip()
                for content in processScriptsGroup(settings, group, encoding):
                    o.write(content + '\n\n')
        for fname_pattern in args.files:
            for fname in glob.glob(fname_pattern):
                o.write(fileContent(fname, encoding, {}) + '\n\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
