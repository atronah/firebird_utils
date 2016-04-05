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
    content = ''
    with open(fname, 'r', encoding=encoding) as f:
        print('processing file: {}'.format(fname))
        content = add_git_info(f.read(), get_git_info(fname))
        try:
            content = content.format(**params)
        except Exception as e:
            print('error "{0}" occured during formating content of file: "{1}"'.format(e, fname))
    return content

            
def parse_file_names(source, settings):
    # if source it is rule (option from [general] section) with sections list, separated by comma
    if settings.has_option('general', source):
        print('browsing rules {}'.format(source))
        # for all sections in rule
        for section in settings['general'][source].split(','):
            section = section.strip()
            #if section not containing 'scripts' option with file names (or file patterns), skip it
            print('browsing section {}'.format(section))
            if not settings.has_option(section, 'scripts'):
                continue
            for fname_pattern in settings[section]['scripts'].split('\n'):
                for fname in glob.glob(fname_pattern):
                    yield fname
    else: #suggest, that source - it is file name or file name pattern
        for fname in glob.glob(source):
            yield fname
                
                
    

def main():
    encoding = 'utf-8'
    
    parser = argparse.ArgumentParser(description='concatenates all scripts in one')
    parser.add_argument('-d', '--dir', dest='dir', default=None, help='directory with scripts')
    parser.add_argument('-o', '--out', dest='out', default=None, help='result file name')
    parser.add_argument('-s', '--settings', dest='settings', default='settings.ini', help='settings file')
    parser.add_argument('-p', '--params', dest='params', default=None
                        , help='name of sections with additional parameters for update (add/rewrite) parameters from [params] section')
    parser.add_argument('sources', default='default', nargs='*'
                        , help='name of option in [general] section with list of sections with rules for making script or file names')
    options = parser.parse_args()

    if options.dir:
        os.chdir(options.dir)

    settings = configparser.ConfigParser()
    settings.read(options.settings)
    
    # получение параметров для подстановки в скрипты
    params = settings['params'] if settings.has_section('params') else {}
    if settings.has_section(options.params):
        params.update(settings[options.params])

    sources = options.sources if type(options.sources) is list else [options.sources] 
          
    if options.out is None:
        options.out = (sources[0] if settings.has_option('general', sources[0])
                                            else 'scripts') \
                      + '.sql'
            
    with open(options.out, 'w', encoding = encoding) as o:
        for source in sources:
            for fname in parse_file_names(source, settings):
                o.write(fileContent(fname, encoding, params) + '\n\n')
                
    
    print('created {}'.format(os.path.abspath(options.out)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
