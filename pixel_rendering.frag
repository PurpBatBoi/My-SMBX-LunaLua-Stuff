#version 120

uniform sampler2D iChannel0;
uniform vec2 iResolution;
uniform float iPixelSize;
uniform vec2 iCamPos;

void main()
{
    // Convert UV to Screen Coordinates
    vec2 screenCoord = gl_TexCoord[0].xy * iResolution;
    
    // Offset by Camera Position to align grid with World Space
    vec2 worldCoord = screenCoord + iCamPos;
    
    // Snap to grid (floor + epsilon for float precision)
    vec2 snappedWorldCoord = floor((worldCoord / iPixelSize) + 0.001) * iPixelSize;
    
    // Convert back to Screen Space relative to camera
    vec2 snappedScreenCoord = snappedWorldCoord - iCamPos;
    
    // Center-sample the texel to avoid linear filtering artifacts (blur)
    vec2 sampleCoord = floor(snappedScreenCoord) + 0.5;
    
    // Output final UV
    gl_FragColor = texture2D(iChannel0, sampleCoord / iResolution);
}