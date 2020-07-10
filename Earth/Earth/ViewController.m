//
//  ViewController.m
//  Earth
//
//  Created by DPP on 2020/7/1.
//  Copyright © 2020 DPP. All rights reserved.
//

#import "ViewController.h"
#import <GLKit/GLKit.h>
#import "GLProgram.h"
#import "UIImage+Categories.h"

#define ScreenWidth     [UIScreen mainScreen].bounds.size.width
#define ScreenHeight    [UIScreen mainScreen].bounds.size.height

typedef struct {
    GLKVector3 positionCoord;
    GLKVector2 textureCoord;
} SenceVertex;

@interface ViewController () {
    GLuint _fbo;    // 帧缓存
    GLuint _rbo;    // 渲染缓存
    GLuint _dbo;    // 深度缓存
    
    GLuint _vbo;    // 顶点缓存
    
    GLuint _positionAttr;
    GLuint _textureCoordAttr;
    GLuint _inputTexture;
    GLuint _mvp;
}

@property (nonatomic, strong) EAGLContext *context;
@property (nonatomic, strong) CAEAGLLayer *eaglLayer;
@property (nonatomic, strong) GLProgram *program;

@property (nonatomic, assign) SenceVertex *vertices;

@property (nonatomic, assign) NSInteger totalCount;

@property (nonatomic, assign) CGFloat currentLongtitude;


@property (nonatomic, strong) CADisplayLink *displayLink;

@property (nonatomic, assign) CGFloat currentAngle;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self setupLayer];
    [self setupProgram];
    [self createVertices];
    [self setupDisplayLink];
}

- (void)setupDisplayLink {
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayAction:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)displayAction:(CADisplayLink *)displayLink {
    self.currentAngle += 0.5;
    [self drawWithAngle:self.currentAngle];
}

- (void)createVertices {
    // buffer data必须在glVertexAttribPointer之前
    
    GLuint numOfU = 30;
    GLuint numOfV = 60;
    self.vertices = malloc(sizeof(SenceVertex) * numOfU * numOfV * 6);
    [self generateWithVertices:self.vertices numOfU:numOfU numOfV:numOfV];
    
    
    self.totalCount = numOfU * numOfV * 6;
    size_t size = sizeof(SenceVertex) * self.totalCount;
    
    glGenBuffers(1, &_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    glBufferData(GL_ARRAY_BUFFER, size, self.vertices, GL_STATIC_DRAW);
    glVertexAttribPointer(_positionAttr, 3, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, positionCoord));
    glVertexAttribPointer(_textureCoordAttr, 2, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, textureCoord));
    
    NSString *imgFilePath = [[NSBundle mainBundle] pathForResource:@"earth5" ofType:@"jpg"];
    UIImage *img = [UIImage imageWithContentsOfFile:imgFilePath];
    GLint texture = [img texture];
    
    glActiveTexture(GL_TEXTURE0);
    glUniform1i(_inputTexture, 0);
    glBindTexture(GL_TEXTURE_2D, texture);
}


- (SenceVertex)caculateCoordinate:(GLfloat)u v:(GLfloat)v {
    GLfloat r = 1.0;
    GLfloat pi = M_PI;
    GLfloat y = r * cos(pi * u);
    GLfloat x = r * sin(pi * u) * sin(2 * pi * v);
    GLfloat z = r * sin(pi * u) * cos(2 * pi * v);
    
    return (SenceVertex){{x, y ,z}, {v, u}};
}

- (void)generateWithVertices:(SenceVertex *)vertices numOfU:(GLuint)numOfU numOfV:(GLuint)numOfV {
    GLfloat uStep = 1.0 / numOfU;
    GLfloat vStep = 1.0 / numOfV;
    
    GLint offset = 0;
    
    for (int u = 0; u < numOfU; u++) {
        for (int v = 0; v < numOfV; v++) {
            SenceVertex point1 = [self caculateCoordinate:u * uStep         v:v * vStep];
            SenceVertex point2 = [self caculateCoordinate:(u + 1) * uStep   v:v * vStep];
            SenceVertex point3 = [self caculateCoordinate:(u + 1) * uStep   v:(v + 1) * vStep];
            SenceVertex point4 = [self caculateCoordinate:u * uStep         v:(v + 1) * vStep];
            
            self.vertices[offset] = point1;
            self.vertices[offset + 1] = point4;
            self.vertices[offset + 2] = point3;
            self.vertices[offset + 3] = point1;
            self.vertices[offset + 4] = point3;
            self.vertices[offset + 5] = point2;
            
            offset += 6;
        }
    }
}

- (void)drawWithAngle:(CGFloat)angle {
    // 矩阵变换
    // 正交投影矩阵
    GLKMatrix4 project = GLKMatrix4MakeOrtho(-1.0, 1.0, -1.0, 1.0, 0.1, 100.0);
    // 观察矩阵
    GLKMatrix4 view = GLKMatrix4MakeLookAt(0.0, 0.0, 3.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0);
    // 模型矩阵
    GLKMatrix4 model = GLKMatrix4Identity;
    model = GLKMatrix4Rotate(model, GLKMathDegreesToRadians(angle), 0.0, 1.0, 0.0);
    
    GLKMatrix4 mvp = GLKMatrix4Identity;
    mvp = GLKMatrix4Multiply(mvp, project);
    mvp = GLKMatrix4Multiply(mvp, view);
    mvp = GLKMatrix4Multiply(mvp, model);
    
    glUniformMatrix4fv(_mvp, 1, GL_FALSE, (GLfloat *)&mvp);
    
    GLint width;
    GLint height;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height);
    
    glViewport(0, 0, width, height);
    
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glEnable(GL_DEPTH_TEST);
//    glEnable(GL_BLEND);

//    glDrawArrays(GL_POINTS, 0, (GLsizei)self.totalCount);
//    glDrawArrays(GL_LINE_LOOP, 0, (GLsizei)self.totalCount);
    glDrawArrays(GL_TRIANGLES, 0, (GLsizei)self.totalCount);
    [self.context presentRenderbuffer:_rbo];
}

- (void)setupLayer {
    self.eaglLayer = [CAEAGLLayer layer];
    self.eaglLayer.frame = CGRectMake(20, 200, ScreenWidth - 40, ScreenWidth - 40);
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

- (void)setupProgram {
    self.program = [[GLProgram alloc] initWithVertexShaderFileName:@"glsl" fragmentShaderFileName:@"glsl"];
    if (![self.program link]) {
        NSLog(@"程序链接错误");
    }
    
    [self.program validate];
    [self.program use];
    
    _positionAttr = [self.program attributeIndex:@"Position"];
    glEnableVertexAttribArray(_positionAttr);
    
    _textureCoordAttr = [self.program attributeIndex:@"InputTextureCoordinate"];
    glEnableVertexAttribArray(_textureCoordAttr);
    
    _inputTexture = [self.program uniformIndex:@"InputImageTexture"];
    _mvp = [self.program uniformIndex:@"mvp"];
}


@end
