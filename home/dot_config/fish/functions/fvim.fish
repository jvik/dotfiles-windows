# Fuzzy find and open file in nvim
function fvim -d "Fuzzy find and open file in nvim"
    set file (fzf)
    and nvim $file
end
