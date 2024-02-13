# GefTau Shaderpack for Minetest 5.8.0
This pack is intended to improve Minetest's visuals by modifying its shader code. Of course, the code is based off of minetest's original shader code. The pack adds the following effects:
- Better Shadow/artificial Light Colors
- Vignette
- Color Grading
- Improved fog colors
- Tinted sunlight
- Translucent Foliage
- Glossy water
- Bumpmaps on blocks
- God Rays

The nice thing about Minetest shaders is that you can modify them easily without having to compile the rest of the game. However, this also means that they have to work with what the engine provides. There are certainly other effects or better ways of implementing the ones provided, but that would require changes to the game's source code, however small they may be.
# Installation
There are two ways of installing the pack. For the first and probably most convenient option, you can set a custom shader path (thanks to siliconsniffer for pointing this out). To do this:
1. Download the provided files (and unzip in the case of a .zip)
2. Put them anywhere on your computer (preferably in your Minetest directory)
3. Go to your Minetest folder
4. Open `minetest.conf` using any text editor
5. Add a new line to the file: `shader_path = [path of the shaderpack]/Minetest-Shaderpack-main`
6. Profit!

To change back, simply change or delete the line in your config file.

A second is to simply replace the original shader files. To do this:
1. Download the provided files (and unzip in the case of a .zip)
2. Go to your Minetest folder
3. Go to `client/shaders`
5. Copy the shaderpack into that folder
6. Make sure the files from the pack overwrite the originals
7. Profit!

If you want to uninstall after doing this, either download the default shaders from [the Minetest repository](https://github.com/minetest/minetest) or create a backup of your current shaders and copy whichever you chose into the `client/shaders` folder.

A little note, if there is some problem with the code itself, Minetest will show error messages. If the game looks unchanged despite there not being any error messages, you probably did not install it correctly (or just have shaders disabled).

# Options and Performance
Of course there is at least some performance impact that comes with these effects. The god rays in particular are quite heavy on the graphics card. The same is somewhat true for the wavy water. If you should run into lag issues, both can be disabled. The bumpmap effect too can be toggled off, if you don't like it:
1. Go to your shaderpack folder folder or the `client/shaders` folder, depending on how you installed
2. Open `nodes_shader/opengl_fragment.glsl` with a text editor of your choosing
3. Comment out one or more of the options `#define ENABLE_GOD_RAYS`, `#define EXPERIMENTAL_BUMPMAP` and `#define ENABLE_FRAGMENT_WAVES` by writing `//` before them.
4. Save changes

There is also an additional option for if you turn off clouds in the graphics settings. Simply repeat the above steps, but remove `//` before the option `#define CLOUDS_DISABLED`. In my opinion this looks a little nicer, because Minetest weather tends to be overcast a lot which washes out a lot of the shadows, but do what you please.

An additional recommendation on my part is to turn the wave length down to a lower value than default and to use an "irrational" value like 6.7234. The lower wave length just generally makes the waves look better and the weird numbers help reduce tiling. You can set this in your game settings under `Shaders -> Waving blocks -> Liquid waves: wave length` or something similar.

# Gallery
![screenshot_20231227_191838](https://github.com/GefullteTaubenbrust2/Minetest-Shaderpack/assets/72752000/0949e6f2-8237-468d-a9d1-197836369409)
![screenshot_20231227_191940](https://github.com/GefullteTaubenbrust2/Minetest-Shaderpack/assets/72752000/bd033452-f440-4a06-b6da-3856a6bc30a1)
![screenshot_20231227_192010](https://github.com/GefullteTaubenbrust2/Minetest-Shaderpack/assets/72752000/aa787c81-93f8-4a9c-be55-eb581e8fc010)
![screenshot_20231227_192054](https://github.com/GefullteTaubenbrust2/Minetest-Shaderpack/assets/72752000/fe7b9fd8-7425-4129-b40c-2b90796931f2)
![screenshot_20231227_193108](https://github.com/GefullteTaubenbrust2/Minetest-Shaderpack/assets/72752000/711e84ed-e1d6-4183-8333-ecb4fbd360f4)
![screenshot_20231227_194858](https://github.com/GefullteTaubenbrust2/Minetest-Shaderpack/assets/72752000/b62aaee3-a66d-41ad-b70c-cf6a63aee579)

