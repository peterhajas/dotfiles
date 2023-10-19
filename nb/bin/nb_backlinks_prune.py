#!/usr/bin/env python3

import os

def remove_backlinks_from_file(file_path):
    with open(file_path, 'r') as file:
        lines = file.readlines()

    with open(file_path, 'w') as file:
        skip = False
        for line in lines:
            if line.startswith("## Backlinks"):
                skip = True
            if not skip:
                file.write(line)

def remove_backlinks_from_directory(directory):
    for root, dirs, files in os.walk(directory):
        for filename in files:
            if filename.endswith(".md"):
                file_path = os.path.join(root, filename)
                remove_backlinks_from_file(file_path)

if __name__ == "__main__":
    # Replace this command with the one that prints the directory path
    directory_command_output = os.popen("nb notebook --path").read().strip()

    if not directory_command_output:
        print("Directory path is not provided.")
    else:
        remove_backlinks_from_directory(directory_command_output)
        print("Backlinks removed from Markdown files in the specified directory and its subdirectories.")
