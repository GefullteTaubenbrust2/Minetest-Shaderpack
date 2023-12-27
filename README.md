# GefTau Shaderpack for Minetest
This pack is intended to improve Minetest's visuals by modifying its shader code. Of course, the code is based off of minetest's original shader code. The pack adds the following effects:
- Better Shadow/artificial Light Colors
- Vignette
- Color Grading
- Translucent Foliage
- Glossy water
- Bumpmaps on blocks
- God Rays

The nice thing about Minetest shaders is that you can modify them easily without having to compile the rest of the game. However, this also means that they have to work with what the engine provides. There are certainly other effects or better ways of implementing the ones provided, but that would require changes to the game's source code, however small they may be.
# Installation
1. Download the provided files
2. Go to your Minetest folder
3. Go to `client/shaders`
5. Copy the shaderpack into that folder
6. Profit!

If you want to uninstall, either download the default shaders from [the Minetest repository](https://github.com/minetest/minetest) or create a backup of your current shaders and copy whichever you chose into the `client/shaders` folder.

# Performance
Of course there is at least some performance impact that comes with these effects. The god rays in particular are quite heavy on the graphics card. The same is somewhat true for the wavy water. If you should run into lag issues, both can be disabled. The bumpmap effect too can be toggled off, if you don't like it:
1. Go to your `client/shaders` folder after installing or the master folder before installing
2. Open `nodes_shader/opengl_fragment.glsl` with a text editor of your choosing
3. Comment out one or more of the options `#define ENABLE_GOD_RAYS`, `#define EXPERIMENTAL_BUMPMAP` and `#define ENABLE_FRAGMENT_WAVES` by writing `//` before them
4. Save changes

# Gallery
![screenshot_20231227_191838](https://github.com/GefullteTaubenbrust2/Minetest-Shaderpack/assets/72752000/0949e6f2-8237-468d-a9d1-197836369409)
![screenshot_20231227_191940](https://github.com/GefullteTaubenbrust2/Minetest-Shaderpack/assets/72752000/bd033452-f440-4a06-b6da-3856a6bc30a1)
![screenshot_20231227_192010](https://github.com/GefullteTaubenbrust2/Minetest-Shaderpack/assets/72752000/aa787c81-93f8-4a9c-be55-eb581e8fc010)
![screenshot_20231227_192054](https://github.com/GefullteTaubenbrust2/Minetest-Shaderpack/assets/72752000/fe7b9fd8-7425-4129-b40c-2b90796931f2)
![screenshot_20231227_193108](https://github.com/GefullteTaubenbrust2/Minetest-Shaderpack/assets/72752000/711e84ed-e1d6-4183-8333-ecb4fbd360f4)

