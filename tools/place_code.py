#!/usr/bin/env python

import os
import re
import sys


class CodePlacement(object):
    def __init__(self, working_dir):
        self._working_dir = working_dir

    def source_file_obj(self, filename):
        return open(os.path.join(self._working_dir, filename))

    def get_source_lines(self, filename, pattern):
        fileobj = self.source_file_obj(filename)
        result = []
        if pattern.strip() == '*':
            result = fileobj.readlines()
        else:
            def_pattern = pattern.replace('def', 'defp?')
            def_re = re.compile(def_pattern)
            whitespace_re = re.compile(r'^ +')
            all_lines = fileobj.readlines()
            adding = False
            indent = -1
            for line in all_lines:
                match = def_re.search(line)
                if match:
                    result.append(line)
                    adding = True
                    wm = whitespace_re.match(line)
                    indent = len(wm.group(0))
                elif adding:
                    result.append(line)
                    if line.strip() == 'end' and line.startswith(" " * indent) and not line[indent].isspace():
                        # last line in the block
                        break
        fileobj.close()
        return result

def replace_code(infile, placer):
    placeholder_re = re.compile(r'^>>> ([a-zA-Z0-9_-]+\.exs?): (.+)$')

    output_lines = []

    # Look for the placeholder pattern
    while True:
        line = infile.readline()
        if not line:
            break

        match = placeholder_re.search(line)
        if match:
            filename = match.group(1)
            pattern = match.group(2)
            source_lines = placer.get_source_lines(filename, pattern)
            output_lines.extend(source_lines)
        else:
            output_lines.append(line)

    return output_lines


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description="Replaces code placeholders in markdown files with the actual source code")
    parser.add_argument("working_dir", help="The directory with source code files")
    parser.add_argument("markdown", help="File with code placeholders")
    parser.add_argument("-o", help="Output filename. Defaults to stdout")
    args = parser.parse_args()

    placer = CodePlacement(args.working_dir)
    with open(args.markdown) as infile:
        output = replace_code(infile, placer)

    if args.o:
        with open(args.o, 'w') as outfile:
            outfile.writelines(output)
    else:
        sys.stdout.writelines(output)
