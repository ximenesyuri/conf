#!/bin/bash

# Get the selected text from the X11 PRIMARY clipboard
selected_text=$(xsel -o)

# Remove whitespace from the selected text
url=$(echo "$selected_text" | tr -d '[:space:]')

# Copy the modified URL to the X11 PRIMARY clipboard
echo -n "$url" | xsel -i -b

# Open the URL in Firefox
firefox "$url"

