#version 120
uniform sampler2D iChannel0; // The Game Scene (To be pixelated)
uniform sampler2D iBgTexture; // The HD Background (Reference)

uniform vec2 iResolution;
uniform float iPixelSize;
uniform vec2 iCamPos;

void main()
{
    // 1. Calculate Standard UVs (HD / Smooth)
    vec2 uvHD = gl_TexCoord[0].xy;

    // 2. Calculate Pixelated UVs (Snapped)
    vec2 screenCoord = uvHD * iResolution;
    vec2 worldCoord = screenCoord + iCamPos;
    vec2 snappedWorldCoord = floor((worldCoord / iPixelSize) + 0.001) * iPixelSize;
    vec2 snappedScreenCoord = snappedWorldCoord - iCamPos;
    vec2 sampleCoord = floor(snappedScreenCoord) + 0.5;
    vec2 uvPixelated = sampleCoord / iResolution;
    
    // 3. Sample the textures
    // Get the pixelated scene color
    vec4 sceneColor = texture2D(iChannel0, uvPixelated);
    
    // Get the pixelated background color (from the reference buffer)
    // We need this to check if the scene pixel IS the background
    vec4 refBgPixelated = texture2D(iBgTexture, uvPixelated);
    
    // 4. The Magic Comparison
    // Calculate the difference between the Scene and the Background at this pixel.
    // If they are almost identical, it means nothing is covering the background.
    float diff = distance(sceneColor.rgb, refBgPixelated.rgb);
    
    if (diff < 0.01) // Tolerance for tiny compression/rounding errors
    {
        // It's the background! Render it in HD (Smooth UV)
        // We sample from iBgTexture directly to get the pure HD look
        gl_FragColor = texture2D(iBgTexture, uvHD);
    }
    else
    {
        // It's a block, player, or NPC! Render pixelated.
        gl_FragColor = sceneColor;
    }
}