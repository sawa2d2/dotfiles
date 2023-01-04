function _peco_gists
  echo $argv | read GIST_ID
  if [ $GIST_ID ]
    curl -sS -H token "Authorization: token $GITHUB_TOKEN" https://api.github.com/gists/"$GIST_ID" | jq '.files | .[] | .filename, .content' | peco --prompt "[ SELECT SNNIPET ] SEARCH>"| tr -d '"' | read RESULT
    commandline -b $RESULT
  end
end

function peco_gists
  curl -sS -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/users/$GITHUB_USER/gists | jq '.[] | [.id], .description' | xargs -n4 | peco --prompt "[ SELECT GIST ] SEARCH>" | cut -d " " -f 2 | read LINE
_peco_gists $LINE
end
