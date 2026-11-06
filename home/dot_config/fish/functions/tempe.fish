# Create and cd into a temporary directory
function tempe -d "Create and cd into a secure temporary directory"
    set tmpdir (mktemp -d)
    cd $tmpdir
    chmod -R 0700 .
    
    if test (count $argv) -eq 1
        mkdir -p $argv[1]
        cd $argv[1]
        chmod -R 0700 .
    end
end
