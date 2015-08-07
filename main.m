//
//  main.m
//  YouTubeKit
//
//  Created by Caleb Benn on 8/7/15.
//  Copyright (c) 2015 Caleb Benn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ExtractorTube.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        ExtractorTube *extractor = [ExtractorTube sharedExtractor];
        [extractor search:@"mWRsgZuwf_8" success:^(NSString *response) {
            
        } failure:^(NSString *error) {
            
        }];
    }
    return 0;
}
