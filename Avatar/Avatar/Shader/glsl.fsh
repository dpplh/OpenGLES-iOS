precision mediump float;

uniform sampler2D InputImageTexture;
uniform float RotateAngle;
uniform bool IncreaseBrightness;

varying vec2 TextureCoordinate;

const float uR = 0.5;

vec2 whirlpool(vec2 texCoord, float angle) {
    if (abs(angle) > 0.0) {
        float res = 100.0;
        vec2 newTexCoord = texCoord;
        
        float radius = res * uR;
        vec2 xy = res * newTexCoord;
        vec2 dxy = xy - vec2(res / 2.0, res / 2.0);
        
        float r = length(dxy);
        float beta = atan(dxy.y, dxy.x) + radians(angle) * 2.0 * (1.0-(r/radius) * (r/radius));
        if (r <= radius) {
            xy = vec2(res/2.0, res/2.0) + r*vec2(cos(beta), sin(beta));
            
            newTexCoord = xy / res;
            
            return newTexCoord;
        } else {
            return texCoord;
        }
    } else {
        return texCoord;
    }
}

void main() {
    vec2 whirlpoolCoord = whirlpool(TextureCoordinate, RotateAngle);
    gl_FragColor = texture2D(InputImageTexture, whirlpoolCoord);
    
    if (IncreaseBrightness && gl_FragColor.a > 0.05) {
        gl_FragColor += vec4(0.2, 0.2, 0.2, 0.0);
    }
}

