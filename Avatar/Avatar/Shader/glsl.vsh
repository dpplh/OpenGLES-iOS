attribute vec4 Position;
attribute vec2 InputTextureCoordinate;

varying vec2 TextureCoordinate;

uniform mat4 mvp;

void main (void) {
    gl_Position = mvp * Position;
    TextureCoordinate = InputTextureCoordinate;
}
