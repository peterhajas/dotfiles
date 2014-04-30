function is_version_controlled_directory
    version_control_repo_type | read repo_type
    # echo -n $repo_type
    echo -n $repo_type | wc -w | read repo_type
    # echo $repo_type
    test $repo_type -gt 0
end
