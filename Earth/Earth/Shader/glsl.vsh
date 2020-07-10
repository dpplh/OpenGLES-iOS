attribute vec4 Position;
attribute vec2 InputTextureCoordinate;

uniform mat4 mvp;

varying vec2 TextureCoordinate;

void main (void) {
    gl_Position = mvp * Position;
    
    TextureCoordinate = InputTextureCoordinate;
}
