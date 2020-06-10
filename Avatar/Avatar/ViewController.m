//
//  ViewController.m
//  Avatar
//
//  Created by DPP on 2020/6/5.
//  Copyright © 2020 DPP. All rights reserved.
//

#import "ViewController.h"
#import <GLKit/GLKit.h>
#import "GLProgram.h"
#import "UIImage+Categories.h"
#import <CoreMotion/CoreMotion.h>

#define ScreenWidth     [UIScreen mainScreen].bounds.size.width
#define ScreenHeight    [UIScreen mainScreen].bounds.size.height
#define RaidusToDegree(r) (r / M_PI * 180.0)

typedef struct {
    GLKVector3 positionCoord;
    GLKVector2 textureCoord;
} SenceVertex;

const GLbyte indexs[] = {
    0, 1, 2, 3
};

@interface ViewController () {
    GLuint _fbo;    // 帧缓存
    GLuint _rbo;    // 渲染缓存
    GLuint _dbo;    // 深度缓存
    
    GLuint _vbo;
    GLuint _ebo;
    
    GLuint _backgroundTexture;
    GLuint _avatarTexture;
    GLuint _prospectTexture;
}

@property (nonatomic, strong) EAGLContext *context;
@property (nonatomic, strong) CAEAGLLayer *eaglLayer;
@property (nonatomic, assign) SenceVertex *vertices;

@property (nonatomic, strong) GLProgram *program;

@property (nonatomic, strong) CADisplayLink *displayLink;

@property (nonatomic, assign) NSInteger currentFrame;

@property (nonatomic, strong) CMMotionManager *motionManager;

@property (nonatomic, assign) CGFloat rollAngle;
@property (nonatomic, assign) CGFloat pitchAngle;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupMotionManager];
    [self setupLayer];
    [self setupProgram];
    [self setupVertices];
    [self setupElements];
    
    // 背景
    NSString *backgroundFilePath = [[NSBundle mainBundle] pathForResource:@"background" ofType:@"jpg"];
    UIImage *backgroundImage = [UIImage imageWithContentsOfFile:backgroundFilePath];
    _backgroundTexture = [backgroundImage texture];
    
    // 阿凡达
    NSString *avatarFilePath = [[NSBundle mainBundle] pathForResource:@"avatar" ofType:@"jpg"];
    UIImage *avatarImage = [UIImage imageWithContentsOfFile:avatarFilePath];
    _avatarTexture = [avatarImage texture];
    
    NSString *prospectFilePath = [[NSBundle mainBundle] pathForResource:@"prospect" ofType:@"jpg"];
    UIImage *prospectImage = [UIImage imageWithContentsOfFile:prospectFilePath];
    _prospectTexture = [prospectImage texture];

//    [self setupDisplayLink];
}

- (void)setupElements {
    glGenBuffers(1, &_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(SenceVertex) * 4, self.vertices, GL_STATIC_DRAW);
    
    glGenBuffers(1, &_ebo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indexs), indexs, GL_STATIC_DRAW);

}

- (void)setupMotionManager {
    self.motionManager = [[CMMotionManager alloc] init];
    self.motionManager.deviceMotionUpdateInterval = 1 / 60.0;
    if ([self.motionManager isDeviceMotionAvailable]) {
        __weak typeof(self) wSelf = self;
        [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
            // 旋转角
            CGFloat roll = motion.attitude.roll;
            // 偏航角
            CGFloat yaw = motion.attitude.yaw;
            // 俯仰角
            CGFloat pitch = motion.attitude.pitch;
            
            CGFloat angleRoll = MIN(RaidusToDegree(roll), 60.0);
            CGFloat anglePitch = MIN(RaidusToDegree(pitch), 60.0);
            
            self.rollAngle = angleRoll ;
            self.pitchAngle = anglePitch;
            
            wSelf.currentFrame++;
            [wSelf update];
        }];
    }
}

- (void)update {
    GLuint positionAttribute = [self.program attributeIndex:@"Position"];
    GLuint textureCoorAttribute = [self.program attributeIndex:@"InputTextureCoordinate"];
    
    GLuint textureUniform = [self.program uniformIndex:@"InputImageTexture"];
    GLuint mvpUniform = [self.program uniformIndex:@"mvp"];
    GLuint rotateAngleUniform = [self.program uniformIndex:@"RotateAngle"];
    GLuint increaseBrightnessUniform = [self.program uniformIndex:@"IncreaseBrightness"];

    glEnableVertexAttribArray(positionAttribute);
    glEnableVertexAttribArray(textureCoorAttribute);

    glVertexAttribPointer(positionAttribute, 3, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, positionCoord));
    glVertexAttribPointer(textureCoorAttribute, 2, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, textureCoord));

    GLint width;
    GLint height;

    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height);

    glClearColor(1.0, 1.0, 1.0, 1.0);

    // 开启混合
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    //
//    glEnable(GL_DEPTH_TEST);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glViewport(0, 0, width, height);


    NSInteger index = self.currentFrame % 120;
    CGFloat scale = 0.0;
    if (index < 60) {
        scale = index / 60.0 * 0.1 ;
    } else {
        scale = (120 - index) / 60.0 * 0.1;
    }

    // 矩阵变换
    // 正交投影矩阵
    GLKMatrix4 project = GLKMatrix4MakeOrtho(-1.0, 1.0, -1.0, 1.0, 0.1, 100.0);
    // 观察矩阵
    GLKMatrix4 view = GLKMatrix4MakeLookAt(0.0, 0.0, 3.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0);
    // 模型矩阵
    GLKMatrix4 avatarModel = GLKMatrix4MakeScale(1.5 + scale, 1.5 + scale, 1.0);
    GLKMatrix4 otherModel = GLKMatrix4MakeScale(1.5 - scale, 1.5 - scale, 1.0);
    
    CGFloat translationX = self.rollAngle / 360.0;
    CGFloat translationY = self.pitchAngle / 360.0;
    
    avatarModel = GLKMatrix4Translate(avatarModel, translationX * 0.8, translationY * 0.8, 1.0);
    otherModel = GLKMatrix4Translate(otherModel, translationX, translationY, 1.0);

    GLKMatrix4 mvp = GLKMatrix4Identity;
    mvp = GLKMatrix4Multiply(mvp, project);
    mvp = GLKMatrix4Multiply(mvp, view);

    GLKMatrix4 backgroundScale = GLKMatrix4Multiply(mvp, otherModel);
    GLKMatrix4 avatarScale = GLKMatrix4Multiply(mvp, avatarModel);
    GLKMatrix4 prospectScale = GLKMatrix4Multiply(mvp, otherModel);

    glActiveTexture(GL_TEXTURE0);
    glUniform1i(textureUniform, 0);
    
    [self.program use];

    // 背景
    glBindTexture(GL_TEXTURE_2D, _backgroundTexture);
    glUniform1i(increaseBrightnessUniform, NO);
    glUniform1f(rotateAngleUniform, self.rollAngle);
    glUniformMatrix4fv(mvpUniform, 1, GL_FALSE, (GLfloat *)&backgroundScale);
    glDrawElements(GL_TRIANGLE_STRIP, sizeof(indexs), GL_UNSIGNED_BYTE, 0);

    // 阿凡达
    glBindTexture(GL_TEXTURE_2D, _avatarTexture);
    glUniform1i(increaseBrightnessUniform, NO);
    glUniform1f(rotateAngleUniform, 0.0);
    glUniformMatrix4fv(mvpUniform, 1, GL_FALSE, (GLfloat *)&avatarScale);
    glDrawElements(GL_TRIANGLE_STRIP, sizeof(indexs), GL_UNSIGNED_BYTE, 0);

    // 前景
    glBindTexture(GL_TEXTURE_2D, _prospectTexture);
    glUniform1i(increaseBrightnessUniform, YES);
    glUniform1f(rotateAngleUniform, 0.0);
    glUniformMatrix4fv(mvpUniform, 1, GL_FALSE, (GLfloat *)&prospectScale);
    glDrawElements(GL_TRIANGLE_STRIP, sizeof(indexs), GL_UNSIGNED_BYTE, 0);

    glDisable(GL_BLEND);
    [self.context presentRenderbuffer:_rbo];
}

- (void)setupDisplayLink {
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayAction:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)displayAction:(CADisplayLink *)displayLink {
    [self update];
    self.currentFrame++;
}

- (void)setupProgram {
    self.program = [[GLProgram alloc] initWithVertexShaderFileName:@"glsl" fragmentShaderFileName:@"glsl"];
    if (![self.program link]) {
        NSLog(@"程序链接错误");
    }
    
    [self.program validate];
}

- (void)setupVertices {
    self.vertices = malloc(sizeof(SenceVertex) * 4);
    self.vertices[0] = (SenceVertex){{ -1.0,  1.0, 0.0 }, {0.0, 1.0}};
    self.vertices[1] = (SenceVertex){{ -1.0, -1.0, 0.0 }, {0.0, 0.0}};
    self.vertices[2] = (SenceVertex){{  1.0,  1.0, 0.0 }, {1.0, 1.0}};
    self.vertices[3] = (SenceVertex){{  1.0, -1.0, 0.0 }, {1.0, 0.0}};
}

- (void)changeVertices {
    self.vertices[0] = (SenceVertex){{ -1.0,  1.0, 0.1 }, {0.0, 1.0}};
    self.vertices[1] = (SenceVertex){{ -1.0, -1.0, 0.1 }, {0.0, 0.0}};
    self.vertices[2] = (SenceVertex){{  1.0,  1.0, 0.1 }, {1.0, 1.0}};
    self.vertices[3] = (SenceVertex){{  1.0, -1.0, 0.1 }, {1.0, 0.0}};
}

- (void)setupLayer {
    self.eaglLayer = [CAEAGLLayer layer];
    self.eaglLayer.frame = CGRectMake(0, 100, ScreenWidth, ScreenWidth);
    [self.view.layer addSublayer:self.eaglLayer];
    
    self.eaglLayer.opaque = YES;
    self.eaglLayer.drawableProperties = @{
        kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8,
        kEAGLDrawablePropertyRetainedBacking: @(NO)
    };
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:self.context];
    
    glGenRenderbuffers(1, &_rbo);
    glBindRenderbuffer(GL_RENDERBUFFER, _rbo);
    
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.eaglLayer];
    
    GLint width;
    GLint height;
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height);
    
    glGenRenderbuffers(1, &_dbo);
    glBindRenderbuffer(GL_RENDERBUFFER, _dbo);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, width, height);
    
    glGenFramebuffers(1, &_fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, _fbo);
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _rbo);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _dbo);
    
    GLuint status =  glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"DPP | FBO创建失败");
    }
    
    glBindRenderbuffer(GL_RENDERBUFFER, _rbo);
}


@end
