#version 120
uniform sampler2D iChannel0;
uniform vec2 iResolution;
uniform float iPixelSize;
uniform vec2 iCamPos;

void main()
{
    // 1. Get current screen pixel coordinate
    vec2 screenCoord = gl_TexCoord[0].xy * iResolution;
    
    // 2. Offset by camera to align the grid with the world (Fixes Jitter)
    vec2 worldCoord = screenCoord + iCamPos;
    
    // 3. Snap to the pixel grid
    // We add a tiny epsilon (0.001) to prevent flickering due to floating point rounding errors
    vec2 snappedWorldCoord = floor((worldCoord / iPixelSize) + 0.001) * iPixelSize;
    
    // 4. Convert back to screen coordinates
    vec2 snappedScreenCoord = snappedWorldCoord - iCamPos;
    
    // 5. THE BLUR FIX:
    // We strictly floor the coordinate to find the pixel's edge, then add 0.5.
    // This forces the GPU to sample the EXACT CENTER of the texel.
    // If we don't do this, sampling at edge (e.g. 100.0) with Linear Filter causes blur.
    vec2 sampleCoord = floor(snappedScreenCoord) + 0.5;
    
    // 6. Convert back to UV (0.0 to 1.0)
    vec2 uv = sampleCoord / iResolution;
    
    gl_FragColor = texture2D(iChannel0, uv);
}