function prompt_char
    set -l PROMPT_COLOR F5A623
    set -l PROMPT_GREEN 99CC99
    set -l PROMPT_RED F2777A
    set -l PROMPT_BLUE 6699CC

    # Fast path: single git invocation covers repo detection, branch, and status.
    set -l status_lines (git status --porcelain=v1 -b 2>/dev/null)
    if test $status -eq 0
        # First line: "## branch...upstream" or "## HEAD (no branch)" or "## No commits yet on branch"
        set -l header $status_lines[1]
        set -l branch (string replace -r '^## ' '' -- $header | string replace -r '\.\.\..*$' '' | string replace -r ' \[.*$' '')

        # Walk remaining lines to figure out staged / untracked / unstaged.
        # XY meanings per git: '??' untracked; X (col 1) staged; Y (col 2) unstaged.
        set -l has_staged 0
        set -l has_untracked 0
        set -l has_unstaged 0
        for line in $status_lines[2..-1]
            set -l xy (string sub -l 2 -- $line)
            if test "$xy" = '??'
                set has_untracked 1
            else
                set -l x (string sub -l 1 -- $xy)
                set -l y (string sub -s 2 -l 1 -- $xy)
                if test "$x" != ' '
                    set has_staged 1
                end
                if test "$y" != ' '
                    set has_unstaged 1
                end
            end
        end

        # Priority: staged > untracked > unstaged (matches legacy prompt_vcs_status).
        if test $has_staged -eq 1
            set PROMPT_COLOR $PROMPT_GREEN
        else if test $has_untracked -eq 1
            set PROMPT_COLOR $PROMPT_BLUE
        else if test $has_unstaged -eq 1
            set PROMPT_COLOR $PROMPT_RED
        end

        set_color $PROMPT_COLOR --bold
        echo -n $branch
    else
        # Slow path: git said no. Fall back to existing helpers for svn/hg (low-frequency).
        set -l repo_type (version_control_repo_type)
        if test "$repo_type" != 'none'
            set -l vcs_status (prompt_vcs_status)
            switch $vcs_status
                case '+'
                    set PROMPT_COLOR $PROMPT_GREEN
                case '?'
                    set PROMPT_COLOR $PROMPT_BLUE
                case '!'
                    set PROMPT_COLOR $PROMPT_RED
            end
            set_color $PROMPT_COLOR --bold
            echo -n (prompt_vcs_info)
        else
            set_color $PROMPT_COLOR --bold
            echo -n '▶'
        end
    end
    set_color normal
    echo -n ' '
end
