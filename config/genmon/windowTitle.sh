!/usr/bin/env zsh

#genmon script for displaying the time
#displays date and time on the tooltip

# set Label = Hello

readonly WINDOW_TITLE=`xdotool getwindowfocus getwindowname`

# Panel
INFO="<txt>"

if [ "$WINDOW_TITLE" == "Xfwm4" ]; then
  INFO+=$(echo "$(whoami)@$(hostname)")
elif [ ${#WINDOW_TITLE} -gt 50 ]; then #limit the length of the title
  # Trim the title and add ellipsis
  INFO+="${WINDOW_TITLE:0:50}..."
else
  INFO+="${WINDOW_TITLE}"
fi

INFO+="</txt>"

# CSS Styling
CSS="<css>"
CSS+=".genmon_value {
#      background-color: #093058; 
      color:#ffffff; 
      padding-left:10px; 
      padding-right:10px; 
    }" 
CSS+="</css>"


# Panel Print
echo -e "${INFO}"

# Add Styling
echo -e "${CSS}"
