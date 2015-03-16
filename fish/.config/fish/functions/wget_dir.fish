function wget_dir -d "Grab a directory with wget"
    wget -e robots=off -r -nc -np "$argv"
end
