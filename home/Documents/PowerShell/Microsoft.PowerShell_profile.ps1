$env:PATH = "$env:PATH;$HOME\bin"

$env:FZF_ALT_C_COMMAND='fd --hidden --type dir'

Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
Set-PsFzfOption -TabExpansion

fnm env --use-on-cd | Out-String | Invoke-Expression

oh-my-posh init pwsh --config ~/.config/ohmyposh/base.toml | Invoke-Expression
