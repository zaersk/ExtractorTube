//
//  ExtractorTube.h
//  YouTubeKit
//
//  Created by Caleb Benn on 8/7/15.
//  Copyright (c) 2015 Caleb Benn. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ExtractorTube : NSObject

+ (ExtractorTube *)sharedExtractor;

- (void)search:(NSString *)identifier success:(void (^)(NSString *response))success failure:(void (^)(NSString* error))failure;

@end
