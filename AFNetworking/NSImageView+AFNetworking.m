//
//  NSImageView+AFNetworking.m
//  QSync
//
//  Created by Tom Li on 20/2/12.
//  Copyright (c) 2012 QVIVO Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#if __MAC_OS_X_VERSION_MIN_REQUIRED

#import "NSImageView+AFNetworking.h"
#import "AFImageCache.h"

static char kAFImageRequestOperationObjectKey;

@interface NSImageView (_AFNetworking)
@property (readwrite, nonatomic, retain, setter = af_setImageRequestOperation:) AFImageRequestOperation *af_imageRequestOperation;
@end

@implementation NSImageView (_AFNetworking)
@dynamic af_imageRequestOperation;
@end

#pragma mark -

@implementation NSImageView (AFNetworking)

- (AFHTTPRequestOperation *)af_imageRequestOperation {
    return (AFHTTPRequestOperation *)objc_getAssociatedObject(self, &kAFImageRequestOperationObjectKey);
}

- (void)af_setImageRequestOperation:(AFImageRequestOperation *)imageRequestOperation {
    objc_setAssociatedObject(self, &kAFImageRequestOperationObjectKey, imageRequestOperation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (NSOperationQueue *)af_sharedImageRequestOperationQueue {
    static NSOperationQueue *_imageRequestOperationQueue = nil;
    
    if (!_imageRequestOperationQueue) {
        _imageRequestOperationQueue = [[NSOperationQueue alloc] init];
        [_imageRequestOperationQueue setMaxConcurrentOperationCount:8];
    }
    
    return _imageRequestOperationQueue;
}

#pragma mark -

- (void)setImageWithURL:(NSURL *)url {
    [self setImageWithURL:url placeholderImage:nil];
}

- (void)setImageWithURL:(NSURL *)url 
       placeholderImage:(NSImage *)placeholderImage
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
    [request setHTTPShouldHandleCookies:NO];
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_6
    [request setHTTPShouldUsePipelining:YES];
#endif
    
    [self setImageWithURLRequest:request placeholderImage:placeholderImage success:nil failure:nil];
}

- (void)setImageWithURLRequest:(NSURLRequest *)urlRequest 
              placeholderImage:(NSImage *)placeholderImage 
                       success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSImage *image))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
{
    if (![urlRequest URL] || (![self.af_imageRequestOperation isCancelled] && [[urlRequest URL] isEqual:[[self.af_imageRequestOperation request] URL]])) {
        return;
    } else {
        [self cancelImageRequestOperation];
    }
    
    NSImage *cachedImage = [[AFImageCache sharedImageCache] cachedImageForURL:[urlRequest URL] cacheName:nil];
    if (cachedImage) {
        self.image = cachedImage;
        self.af_imageRequestOperation = nil;
        
        if (success) {
            success(nil, nil, cachedImage);
        }
    } else {
        self.image = placeholderImage;
        
        AFImageRequestOperation *requestOperation = [[[AFImageRequestOperation alloc] initWithRequest:urlRequest] autorelease];
        [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            if ([[urlRequest URL] isEqual:[[self.af_imageRequestOperation request] URL]]) {
                self.image = responseObject;
            } else {
                self.image = placeholderImage;
            }
            
            if (success) {
                success(operation.request, operation.response, responseObject);
            }
            
            [[AFImageCache sharedImageCache] cacheImageData:operation.responseData forURL:[urlRequest URL] cacheName:nil];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            if (failure) {
                failure(operation.request, operation.response, error);
            }
        }];
        
        self.af_imageRequestOperation = requestOperation;
        
        [[[self class] af_sharedImageRequestOperationQueue] addOperation:self.af_imageRequestOperation];
    }
}

- (void)cancelImageRequestOperation {
    [self.af_imageRequestOperation cancel];
}

@end

#endif
