# Shell

set PATH $PATH ~/bin;

# Editor

## Alias `mate` to `mvim`, because muscle memory is strong

alias mate mvim

# Shell management

## Easily open this file

alias confedit "mate ~/.config/fish/config.fish"

# Set a greeting

set fish_greeting hello

# Prompt Stuff

## Version Control Status

### This is all a work in progress, and doesn't really work.

function version_control_prompt_character
    git branch >/dev/null 2>/dev/null; and echo '±'; and return
    # hg root >/dev/null 2>/dev/null; and echo '☿'; and return
    svn info >/dev/null 2>/dev/null; and echo '§'; and return
    echo '○'
end

function version_control_repo_type
    if test -d ./.git
        echo -n  git
    else if test -d ./.svn
        echo -n  svn
    else if test -d ./.hg
        echo -n  hg
    else
        echo -n  ''
    end
end

function is_version_controlled_directory
    version_control_repo_type | read repo_type
    # echo -n $repo_type
    echo -n $repo_type | wc -w | read repo_type
    # echo $repo_type
    test $repo_type -gt 0
end

# function version_control_current_branch
#     is_version_controlled_directory | read $is_vcs_dir
    
#     switch $is_vcs_dir
#         case git


#     if test -d ./.git
#         git rev-parse --abbrev-ref HEAD
#     else
#         echo ''
#     end
# end

function version_control_info
    version_control_prompt_character; and echo -n " "; and echo -n "["; and version_control_current_branch; and echo -n "]"
end

## Eventually, the right prompt will show VCS information

function fish_right_prompt
    # version_control_info
end
