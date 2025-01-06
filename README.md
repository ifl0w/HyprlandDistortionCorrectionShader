Hyprland Distortion Correction Shader for Curved Monitors
=========

This repo contains a simple shader which can be directly be used with [Hyprland's screen_shader feature](https://wiki.hyprland.org/Configuring/Variables/#decoration) to correct for the distortion of a curved monitor in games and videos.
When configured correctly, straight lines in games should appear straight on a curved monitor. 
This might also help with motion sickness and make gaming more comfortable.

The shader code implements a simple remapping of a linear projection to a cylindrical projection.
Note that this implementation is not correct for most content because the exact projection in games or cameras used during filming is unknown in the shader (this would require integration into the game engine and exact camera information).
In other words, this is just an optimistic experiment to correct the distortion of a curved monitor by assuming the content is generated/projected for the exact viewpoint and cylindrical display geometry that is configured in the shader code.

**Important Notes:**
* Parameters such as view position and display geometry currently have to be change directly in the code (see the top of the shader code for parameter constants)
* Any 2D content (e.g., 2D games or user interfaces) will not really benefit from this
* Whether this shader actually improves gaming experience also depends on personal preference and how well the game/content and this shader is configured

-------- 

More information about about various methods for real-time distortion correction can be found in my master's thesis ["Real-time Distortion Correction Methods for Curved Monitors"](https://repositum.tuwien.at/handle/20.500.12708/139835).
