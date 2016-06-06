import sys
import re



def main():
    if len(sys.argv) != 2:
        print('incorrect use, need only 1 argument: filename')
        return 1
    
    info = {}
    table_name_pattern = re.compile(r'(\w+)\s+\(\d+\)')
    records_info_pattern = re.compile(r'^\s+.+total records:\s+(\d+)')
    page_info_pattern = re.compile(r'^\s+Data pages:\s+(\d+)')
    
    with open(sys.argv[1], 'r') as f:
        for line in f:
            match = table_name_pattern.match(line)
            if match:
                table_info = info.setdefault(match.group(1), {})
            match = records_info_pattern.match(line)
            if match:
                table_info['records_count'] = match.group(1)
            match = page_info_pattern.match(line)
            if match:
                table_info['pages_count'] = match.group(1)
    
    table_names = list(info.keys())
    table_names = sorted(table_names, key=lambda table_name: int(info[table_name]['pages_count']))
    for name in table_names:
        print(name, info[name]['records_count'], info[name]['pages_count'])
        
    
    

if __name__ == '__main__':
    main()