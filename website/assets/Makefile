.PHONY: all
all: demo.gif demo-adding.gif demo-listing.gif demo-notify.gif

%.gif: %.mp4
	ffmpeg -i $< -vf "fps=15,scale=520:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 $@
