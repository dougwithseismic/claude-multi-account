-- Hands claude:// links to the Claude instance used last (via Hammerspoon), or to the first instance if Hammerspoon isn't running.
on open location theURL
	do shell script "/opt/homebrew/bin/hs -c " & quoted form of ("claudeAB.openURL([==[" & theURL & "]==])") & " || open -b com.anthropic.claudefordesktop " & quoted form of theURL
end open location
