//
//  ExtractorTube.m
//  YouTubeKit
//
//  Created by Caleb Benn on 8/7/15.
//  Copyright (c) 2015 Caleb Benn. All rights reserved.
//

#import "ExtractorTube.h"
#import <JavaScriptCore/JavaScriptCore.h>

static NSString* const ytDummySignature = @"BC46474764CD5E86EBFECD43C5692A50528C66A2F45.A3A45BF375942288144D567BC990BD0A09483A1111";

static ExtractorTube *_instance = nil;

@interface ExtractorTube()
{
    JSContext *_jsContext;
}
@end
@implementation ExtractorTube

+ (ExtractorTube *)sharedExtractor {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [ExtractorTube new];
    });
    
    return _instance;
}

- (id)init {
    if (self = [super init]) {
        _jsContext = [JSContext new];
    }
    return self;
}

- (void)search:(NSString *)identifier success:(void (^)(NSString *))success failure:(void (^)(NSString *))failure {
    
    __weak typeof(self)weakSelf = self;
    
    NSString *reqString = [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@&spf=prefetch",identifier];
    
    // NSLog(@"%@", [self extractSignature:identifier]);
    
    [self extractSource:reqString success:^(NSData *response) {
        NSError *jsonError;
        
        NSArray *respArr = [NSJSONSerialization JSONObjectWithData:response options:0 error:&jsonError];
        if (!jsonError) {
            NSDictionary *respDict = [respArr objectAtIndex:1];
            
            NSString *headStr = [respDict objectForKey:@"head"];
            
            NSString *pattern = @"//[\\w-]+(\\.[\\w-]+)+([\\w.,@?^=%&amp;:/~+#-]*[\\w@?^=%&amp;/~+#-])?";
            NSRegularExpression *reg = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                 options:NSRegularExpressionCaseInsensitive
                                                                                   error:NULL];
            NSTextCheckingResult *result = [reg firstMatchInString:headStr
                                                           options:(NSMatchingOptions)0
                                                             range:NSMakeRange(0, headStr.length)];
            NSString *infoObjStr = (result.numberOfRanges > 1) ? [headStr substringWithRange:[result rangeAtIndex:0]] : nil;
            NSString *playerJSUrl = [NSString stringWithFormat:@"http:%@",infoObjStr];
            
            NSLog(@"url: %@",playerJSUrl);
            
            //Extract Info
            // id infoObj = [weakSelf extractInfo:identifier];
            // NSLog(@"info %@",infoObj);
            // NSLog(@"%@",[[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
            
            [weakSelf extractSource:playerJSUrl success:^(NSData *response) {
                // NSString *respString = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
                // NSLog(@"js: %@",respString);
                
                // NSLog(@"%@", [weakSelf extractDecryptionFuncName:response]);
                /*
                NSURL *scriptURL = [NSURL URLWithString:@"https://ajax.googleapis.com/ajax/libs/jquery/2.1.3/jquery.min.js"];
                NSError *error = nil;
                NSString *script = [NSString stringWithContentsOfURL:scriptURL encoding:NSUTF8StringEncoding error:&error];
                [_jsContext evaluateScript:script];
                NSLog(@"%@",[[_jsContext exception] toString]);
                */
                
                [_jsContext evaluateScript:[[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]];
                NSLog(@"%@",[[_jsContext exception] toString]);
                
                NSString *decryptionFuncName = [weakSelf extractDecryptionFuncName:response];
                if (!decryptionFuncName) {
                    NSLog(@"ERROR: NO FUNC NAME");
                    return;
                }
                
                NSString *decryptionFunc = [weakSelf extractDecryptionFunc:response withFunctionName:decryptionFuncName];
                if (!decryptionFuncName) {
                    NSLog(@"ERROR: NO DECRYPTION FUNC");
                    return;
                }
                NSLog(@"%@", decryptionFunc);
                
                [_jsContext evaluateScript:decryptionFunc];
                NSLog(@"%@",[[_jsContext exception] toString]);
                
                NSString *decryptionFuncProperty = [weakSelf validateDecryptionFunc:response withFunctionName:decryptionFuncName];
                if (!decryptionFuncProperty) {
                    NSLog(@"Could not validate func property");
                    return;
                }
                
                [_jsContext evaluateScript:decryptionFuncProperty];
                
                NSLog(@"done!");
                 
                
            } failure:^(NSString *error) {
                NSLog(@"Error %@", error);
            }];
            
            
        } else {
            NSLog(@"Error parsing json.");
        }
    } failure:^(NSString *error) {
        NSLog(@"An error occurred (1). %@",error);
    }];
}

- (id)extractInfo:(NSString *)identifier {
    
    NSString *reqString = [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@",identifier];
    
    __block NSString *infoObj_ = nil;
    
    [self extractSource:reqString success:^(NSData *response) {
        
        NSString *regPtn = @"<script>(.*);ytplayer.load";
        
        NSString *str = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
        
        NSRegularExpression *reg = [NSRegularExpression regularExpressionWithPattern:regPtn
                                                                             options:NSRegularExpressionCaseInsensitive
                                                                               error:NULL];
        NSTextCheckingResult *result = [reg firstMatchInString:str
                                                       options:(NSMatchingOptions)0
                                                         range:NSMakeRange(0, str.length)];
        NSString *infoObjStr = (result.numberOfRanges > 1) ? [str substringWithRange:[result rangeAtIndex:1]] : nil;
        if (!infoObjStr) {
            return;
        }
        
        [_jsContext evaluateScript:infoObjStr];
        NSLog(@"%@",infoObjStr);
        JSValue *infoObjValue = _jsContext[@"ytplayer"];
        
        infoObj_ = (NSString *)[infoObjValue toObject];
        
    } failure:^(NSString *error) {
        NSLog(@"An error occurred (1). %@",error);
    }];
    
    return infoObj_;
}

- (id)extractSignature:(NSString *)identifier {
    NSString *reqString = [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@",identifier];
    
    __block NSString *sig_ = nil;
    
    [self extractSource:reqString success:^(NSData *response) {
        NSString *regPtn = @"(?=signature)(.*?)[^\\]*";
        
        NSString *str = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];

        NSRegularExpression *reg = [NSRegularExpression regularExpressionWithPattern:regPtn
                                                                             options:NSRegularExpressionCaseInsensitive
                                                                               error:NULL];
        NSTextCheckingResult *result = [reg firstMatchInString:str
                                                       options:(NSMatchingOptions)0
                                                         range:NSMakeRange(0, str.length)];
        NSString *sig_str = (result.numberOfRanges > 1) ? [str substringWithRange:[result rangeAtIndex:1]] : nil;
        if (!sig_str) {
            return;
        }
        
        sig_ = sig_str;
    } failure:^(NSString *error) {
        NSLog(@"An error occurred (3). %@",error);
    }];
    
    return sig_;
    
}

- (id)extractDecryptionFuncName:(NSData *)data {
    NSString *regPtn = @"set\\([\"']signature[\"']\\s*,\\s*(.*)\\((.*)\\)\\)";
    
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSRegularExpression *reg = [NSRegularExpression regularExpressionWithPattern:regPtn
                                                                         options:0
                                                                           error:NULL];
    NSTextCheckingResult *result = [reg firstMatchInString:str
                                                   options:(NSMatchingOptions)0
                                                     range:NSMakeRange(0, str.length)];
    NSString *funcName = (result.numberOfRanges > 1) ? [str substringWithRange:[result rangeAtIndex:1]] : nil;
    return funcName;
}

- (id)extractDecryptionFunc:(NSData *)data withFunctionName:(NSString *)funcName {
    NSString *regPtn = @"function %@\\((.*)\\)\\s*\\{(.*)\\};";
    
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSString *regStr = [NSString stringWithFormat:regPtn, funcName];
    NSRegularExpression *reg = [NSRegularExpression regularExpressionWithPattern:regStr
                                                                         options:NSRegularExpressionCaseInsensitive
                                                                           error:NULL];
    NSTextCheckingResult *result = [reg firstMatchInString:str
                                                   options:(NSMatchingOptions)0
                                                     range:NSMakeRange(0, str.length)];
    NSString *funcStr = (result.numberOfRanges > 1) ? [str substringWithRange:[result rangeAtIndex:0]] : nil;
    return funcStr;
}

- (id)validateDecryptionFunc:(NSData *)data withFunctionName:(NSString *)funcName {
    
    [_jsContext evaluateScript:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
    NSLog(@"%@",[[_jsContext exception] toString]);
    
    [_jsContext evaluateScript:[NSString stringWithFormat:@"%@('%@')", funcName, ytDummySignature]];
    
    NSString *exception = [[_jsContext exception] toString];
    NSLog(@"%@",exception);
    
    NSString *funcName2 = [exception stringByReplacingOccurrencesOfString:@"ReferenceError: Can't find variable: " withString:@""];
    
    NSString *regPtn = @"var %@\\s*=\\s*\\{(.*)\\};";
    NSString *regStr = [NSString stringWithFormat:regPtn, funcName2];
    NSRegularExpression *reg = [NSRegularExpression regularExpressionWithPattern:regStr
                                                                         options:NSRegularExpressionCaseInsensitive
                                                                           error:NULL];
    
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSTextCheckingResult *result = [reg firstMatchInString:str
                                                   options:(NSMatchingOptions)0
                                                     range:NSMakeRange(0, str.length)];
    NSString *varStr = (result.numberOfRanges > 1) ? [str substringWithRange:[result rangeAtIndex:0]] : nil;

    return varStr;
}

- (void)extractSource:(NSString *)urlString success:(void (^)(NSData *response))success failure:(void (^)(NSString* error))failure {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [request setHTTPMethod: @"GET"];
    
    NSError *requestError;
    NSURLResponse *urlResponse = nil;
    
    NSData *response = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&requestError];
    NSString *respString = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
    
    NSData *data = [respString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    
    if (!error && data) {
        success(data);
    } else {
        failure(error.localizedDescription);
    }
}
@end
