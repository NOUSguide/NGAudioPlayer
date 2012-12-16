//
//  NGAudioPlayer.m
//  NGAudioPlayer
//
//  Created by Matthias Tretter on 21.06.12.
//
//  Contributors:
//  -------------
//  Matthias Tretter (@myell0w)
//  Manfred Scheiner (@scheinem)
//  Alexander Wolf
//
//  Copyright (c) 2012 NOUS Wissensmanagement GmbH. All rights reserved.
//

#import "NGAudioPlayer.h"
#import "NGAudioPlayerControlResponder.h"

#define kNGAudioPlayerKeypathRate           NSStringFromSelector(@selector(rate))
#define kNGAudioPlayerKeypathStatus         NSStringFromSelector(@selector(status))
#define kNGAudioPlayerKeypathCurrentItem    NSStringFromSelector(@selector(currentItem))
#define kNGAudioPlayerKeypathPlayback       NSStringFromSelector(@selector(playbackLikelyToKeepUp))

static char rateContext;
static char statusContext;
static char currentItemContext;

@interface NGAudioPlayer () {
    // flags for methods implemented in the delegate
    struct {
        unsigned int didStartPlaybackOfURL:1;
        unsigned int didFinishPlaybackOfURL:1;
        unsigned int didChangePlaybackState:1;
        unsigned int didFail:1;
	} _delegateFlags;
}

@property (nonatomic, strong) AVQueuePlayer *player;
@property (nonatomic, readonly) CMTime CMDurationOfCurrentItem;
@property (nonatomic, strong) NGAudioPlayerControlResponder *controlResponder;
@property (nonatomic, assign, readwrite) NGAudioPlayerPlaybackState playbackState;

- (NSURL *)URLOfItem:(AVPlayerItem *)item;
- (CMTime)CMDurationOfItem:(AVPlayerItem *)item;
- (NSTimeInterval)durationOfItem:(AVPlayerItem *)item;

- (void)handleRateChange:(NSDictionary *)change;
- (void)handleStatusChange:(NSDictionary *)change;
- (void)handleCurrentItemChange:(NSDictionary *)change;
- (void)playerItemDidPlayToEndTime:(NSNotification *)notification;

@end

@implementation NGAudioPlayer

////////////////////////////////////////////////////////////////////////
#pragma mark - Lifecycle
////////////////////////////////////////////////////////////////////////

+ (void)initialize {
    if (self == [NGAudioPlayer class]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            (void)[self initBackgroundAudio];
        });
    }
}

- (id)initWithURLs:(NSArray *)urls {
    if ((self = [super init])) {
        if (urls.count > 0) {
            NSMutableArray *items = [NSMutableArray arrayWithCapacity:urls.count];
            
            for (NSURL *url in urls) {
                if ([url isKindOfClass:[NSURL class]]) {
                    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
                    [items addObject:item];
                    
                }
            }
            
            [(AVPlayerItem *)[items objectAtIndex:0] addObserver:self
                                                      forKeyPath:kNGAudioPlayerKeypathPlayback
                                                         options:NSKeyValueObservingOptionNew
                                                         context:nil];
            
            _player = [AVQueuePlayer queuePlayerWithItems:items];
        } else {
            _player = [AVQueuePlayer queuePlayerWithItems:nil];
        }
        
        [_player addObserver:self forKeyPath:kNGAudioPlayerKeypathRate options:NSKeyValueObservingOptionNew context:&rateContext ];
        [_player addObserver:self forKeyPath:kNGAudioPlayerKeypathStatus options:NSKeyValueObservingOptionNew context:&statusContext];
        [_player addObserver:self forKeyPath:kNGAudioPlayerKeypathCurrentItem options:NSKeyValueObservingOptionNew context:&currentItemContext];
		
        _automaticallyUpdateNowPlayingInfoCenter = YES;
        self.usesMediaControls = YES;
        _removeAllURLsOnPlaybackStop = NO;
        
        _delegate_queue = dispatch_get_main_queue();
        
        self.playbackState = NGAudioPlayerPlaybackStateInitialized;
    }
    
    return self;
}

- (id)initWithURL:(NSURL *)url {
    return [self initWithURLs:[NSArray arrayWithObject:url]];
}

- (id)init {
    return [self initWithURLs:nil];
}

- (void)dealloc {
    [_player removeObserver:self forKeyPath:kNGAudioPlayerKeypathRate];
    [_player removeObserver:self forKeyPath:kNGAudioPlayerKeypathStatus];
    [_player removeObserver:self forKeyPath:kNGAudioPlayerKeypathCurrentItem];
}

////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject KVO
////////////////////////////////////////////////////////////////////////

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &rateContext && [keyPath isEqualToString:kNGAudioPlayerKeypathRate]) {
        [self handleRateChange:change];
    } else if (context == &statusContext && [keyPath isEqualToString:kNGAudioPlayerKeypathStatus]) {
        [self handleStatusChange:change];
    } else if (context == &currentItemContext && [keyPath isEqualToString:kNGAudioPlayerKeypathCurrentItem]) {
        [self handleCurrentItemChange:change];
    } else if (object == self.player.currentItem && [keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        [self handlePlaybackStatusChange:change];
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - NGAudioPlayer Properties
////////////////////////////////////////////////////////////////////////

- (BOOL)isPlaying {
    return self.playbackState == NGAudioPlayerPlaybackStatePlaying;
}

- (void)setPlaybackState:(NGAudioPlayerPlaybackState)playbackState {
    if (_playbackState != playbackState) {
        _playbackState = playbackState;
        if (_delegateFlags.didChangePlaybackState) {
            dispatch_async(self.delegate_queue, ^{
                [self.delegate audioPlayerDidChangePlaybackState:_playbackState];
            });
        }
    }
}

- (NSURL *)currentPlayingURL {
    return [self URLOfItem:self.player.currentItem];
}

- (NSTimeInterval)durationOfCurrentPlayingURL {
    return [self durationOfItem:self.player.currentItem];
}

- (NSArray *)enqueuedURLs {
    NSArray *items = self.player.items;
    NSArray *itemsWithURLAssets = [items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [self URLOfItem:evaluatedObject] != nil;
    }]];
    
    NSAssert(items.count == itemsWithURLAssets.count, @"All Assets should be AVURLAssets");
    
    return [itemsWithURLAssets valueForKey:@"URL"];
}

- (void)setDelegate:(id<NGAudioPlayerDelegate>)delegate {
    if (delegate != _delegate) {
        _delegate = delegate;
        
        _delegateFlags.didStartPlaybackOfURL = [delegate respondsToSelector:@selector(audioPlayer:didStartPlaybackOfURL:)];
        _delegateFlags.didFinishPlaybackOfURL = [delegate respondsToSelector:@selector(audioPlayer:didFinishPlaybackOfURL:)];
        _delegateFlags.didChangePlaybackState = [delegate respondsToSelector:@selector(audioPlayerDidChangePlaybackState:)];
        _delegateFlags.didFail = [delegate respondsToSelector:@selector(audioPlayer:didFailForURL:)];
    }
}

- (BOOL)usesMediaControls {
    if (self.controlResponder == nil) {
        return NO;
    }
    return self.controlResponder.respondingToControls;
}

- (void)setUsesMediaControls:(BOOL)usesMediaControls {
    if (usesMediaControls) {
        if (self.controlResponder == nil) {
            self.controlResponder = [[NGAudioPlayerControlResponder alloc] initWithAudioPlayer:self];
        }
        self.controlResponder.respondingToControls = YES;
    }
    else {
        self.controlResponder.respondingToControls = NO;
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - NGAudioPlayer Class Methods
////////////////////////////////////////////////////////////////////////

+ (BOOL)setAudioSessionCategory:(NSString *)audioSessionCategory {
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:audioSessionCategory
                                           error:&error];
    
    if (error != nil) {
        NSLog(@"There was an error setting the AudioCategory to %@", audioSessionCategory);
        return NO;
    }
    
    return YES;
}

+ (BOOL)initBackgroundAudio {
    if (![self setAudioSessionCategory:AVAudioSessionCategoryPlayback]) {
        return NO;
    }
    
    NSError *error = nil;
	if (![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
		NSLog(@"Unable to set AudioSession active: %@", error);
        
        return NO;
	}
    
    return YES;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - NGAudioPlayer Playback
////////////////////////////////////////////////////////////////////////

- (void)playURL:(NSURL *)url {
    if (url != nil) {
        [self removeAllURLs];
        [self enqueueURL:url];
        [self play];
    }
}

- (void)play {
    [self.player play];
}

- (void)pause {
    [self.player pause];
}

- (void)stop {
    [self pause];
    NSArray *urls = [self enqueuedURLs];
    [self removeAllURLs];
    if (!self.removeAllURLsOnPlaybackStop) {
        [self enqueueURLs:urls];
    }
}

- (void)togglePlayback {
    if (self.playing) {
        [self pause];
    } else {
        [self play];
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - NGAudioPlayer Queuing
////////////////////////////////////////////////////////////////////////

- (BOOL)enqueueURL:(NSURL *)url {
    if ([url isKindOfClass:[NSURL class]]) {
        AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
        
        if ([self.player canInsertItem:item afterItem:nil]) {
            [self.player insertItem:item afterItem:nil];
            
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)enqueueURLs:(NSArray *)urls {
    BOOL successfullyAdded = YES;
    
    for (NSURL *url in urls) {
        if ([url isKindOfClass:[NSURL class]]) {
            successfullyAdded = successfullyAdded && [self enqueueURL:url];
        }
    }
    
    return successfullyAdded;
}

- (BOOL)enqueuePlayerItem:(AVPlayerItem *)item {
    if ([item isKindOfClass:[AVPlayerItem class]]) {
        if ([self.player canInsertItem:item afterItem:nil] && [item.asset isKindOfClass:[AVURLAsset class]]) {
            [self.player insertItem:item afterItem:nil];
            
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)enqueueItems:(NSArray *)items {
    BOOL successfullyAdded = YES;
    
    for (AVPlayerItem *item in items) {
        if ([item isKindOfClass:[AVPlayerItem class]]) {
            successfullyAdded = successfullyAdded && [self enqueuePlayerItem:item];
        }
    }
    
    return successfullyAdded;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - NGAudioPlayer Removing
////////////////////////////////////////////////////////////////////////

- (BOOL)removeURL:(NSURL *)url {
    NSArray *items = self.player.items;
    NSArray *itemsWithURL = [items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [[self URLOfItem:evaluatedObject] isEqual:url];
    }]];
    
    // We only remove the first item with this URL (there should be a maximum of one)
    if (itemsWithURL.count > 0) {
        [self.player removeItem:[itemsWithURL objectAtIndex:0]];
        
        return YES;
    }
    
    return NO;
}

- (void)removeAllURLs {
    [self.player removeAllItems];
}

////////////////////////////////////////////////////////////////////////
#pragma mark - NGAudioPlayer Advancing
////////////////////////////////////////////////////////////////////////

- (void)advanceToNextURL {
    [self.player advanceToNextItem];
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Private
////////////////////////////////////////////////////////////////////////

- (NSURL *)URLOfItem:(AVPlayerItem *)item {
    if ([item isKindOfClass:[AVPlayerItem class]]) {
        AVAsset *asset = item.asset;
        
        if ([asset isKindOfClass:[AVURLAsset class]]) {
            AVURLAsset *urlAsset = (AVURLAsset *)asset;
            
            return urlAsset.URL;
        }
    }
    
    return nil;
}

- (CMTime)CMDurationOfCurrentItem {
    return [self CMDurationOfItem:self.player.currentItem];
}

- (CMTime)CMDurationOfItem:(AVPlayerItem *)item {
    // Peferred in HTTP Live Streaming
    if ([item respondsToSelector:@selector(duration)] && // 4.3
        item.status == AVPlayerItemStatusReadyToPlay) {
        
        if (CMTIME_IS_VALID(item.duration)) {
            return item.duration;
        }
    }
    
    else if (CMTIME_IS_VALID(item.asset.duration)) {
        return item.asset.duration;
    }
    
    return kCMTimeInvalid;
}

- (NSTimeInterval)durationOfItem:(AVPlayerItem *)item {
    return CMTimeGetSeconds([self CMDurationOfItem:item]);
}

- (void)handleRateChange:(NSDictionary *)change {
    float rate = [[change valueForKey:NSKeyValueChangeNewKey] floatValue];
    if (rate > 0.f) {
        if (self.player.currentItem.playbackLikelyToKeepUp) {
            self.playbackState = NGAudioPlayerPlaybackStatePlaying;
        }
        else {
            self.playbackState = NGAudioPlayerPlaybackStateReadyToPlay;
        }
    }
    else {
        self.playbackState = NGAudioPlayerPlaybackStatePaused;
    }
}

- (void)handleStatusChange:(NSDictionary *)change {
    AVPlayerStatus newStatus = (AVPlayerStatus)[[change valueForKey:NSKeyValueChangeNewKey] intValue];
    
    if (newStatus == AVPlayerStatusFailed) {
        if (_delegateFlags.didFail) {
            dispatch_async(self.delegate_queue, ^{
                [self.delegate audioPlayer:self didFailForURL:self.currentPlayingURL];
            });
        }
    }
}

- (void)handlePlaybackStatusChange:(NSDictionary *)change {
    BOOL bufferingFinished = [[change valueForKey:NSKeyValueChangeNewKey] boolValue];
    if (bufferingFinished) {
        if (self.player.rate > 0.f) {
            self.playbackState = NGAudioPlayerPlaybackStatePlaying;
        }
    }
    else {
        self.playbackState = NGAudioPlayerPlaybackStateBuffering;
    }
}

- (void)handleCurrentItemChange:(NSDictionary *)change {
    AVPlayerItem *oldItem = (AVPlayerItem *)[change valueForKey:NSKeyValueChangeOldKey];
    AVPlayerItem *newItem = (AVPlayerItem *)[change valueForKey:NSKeyValueChangeNewKey];
    
    if (oldItem != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:oldItem];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemFailedToPlayToEndTimeNotification
                                                      object:oldItem];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:@"playbackLikelyToKeepUp"
                                                      object:oldItem];
        
        [oldItem removeObserver:self forKeyPath:kNGAudioPlayerKeypathPlayback];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidPlayToEndTime:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:newItem];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidFailToPlayToEnd:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:newItem];
    
    [newItem addObserver:self
              forKeyPath:kNGAudioPlayerKeypathPlayback
                 options:NSKeyValueObservingOptionNew
                 context:nil];
    
    
    NSURL *url = [self URLOfItem:newItem];
    NSDictionary *nowPlayingInfo = url.ng_nowPlayingInfo;
	
    if (url != nil && self.playing && _delegateFlags.didStartPlaybackOfURL) {
        dispatch_async(self.delegate_queue, ^{
            [self.delegate audioPlayer:self didStartPlaybackOfURL:url];
        });
    }
    
    if (self.automaticallyUpdateNowPlayingInfoCenter && NSClassFromString(@"MPNowPlayingInfoCenter") != nil) {
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nowPlayingInfo;
    }
}

- (void)playerItemDidPlayToEndTime:(NSNotification *)notification {
    if (_delegateFlags.didFinishPlaybackOfURL) {
        NSURL *url = [self URLOfItem:notification.object];
        
        if (url != nil) {
            dispatch_async(self.delegate_queue, ^{
                [self.delegate audioPlayer:self didFinishPlaybackOfURL:url];
            });
        }
    }
}

- (void)playerItemDidFailPlayToEndTime:(NSNotification *)notification {
    if (_delegateFlags.didFail) {
        NSURL *url = [self URLOfItem:notification.object];
        
        if (url != nil) {
            dispatch_async(self.delegate_queue, ^{
                [self.delegate audioPlayer:self didFailForURL:url];
            });
        }
    }
}

- (void)fadePlayerFromVolume:(CGFloat)fromVolume toVolume:(CGFloat)toVolume duration:(NSTimeInterval)duration {
    CMTime startFadeOutTime = CMTimeMakeWithSeconds(0.0, 1);
    CMTime endFadeOutTime = CMTimeMakeWithSeconds(duration, 1);
    CMTimeRange fadeInTimeRange = CMTimeRangeFromTimeToTime(startFadeOutTime, endFadeOutTime);
    
    AVPlayerItem *playerItem = self.player.currentItem;
    
    AVAsset *asset = playerItem.asset;
    NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    
    NSMutableArray *allAudioParams = [NSMutableArray array];
    for (AVAssetTrack *track in audioTracks) {
        AVMutableAudioMixInputParameters *audioInputParams = [AVMutableAudioMixInputParameters audioMixInputParameters];
        [audioInputParams setVolumeRampFromStartVolume:fromVolume toEndVolume:toVolume timeRange:fadeInTimeRange];
        [audioInputParams setTrackID:[track trackID]];
        [allAudioParams addObject:audioInputParams];
    }
    
    AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
    [audioMix setInputParameters:allAudioParams];
    
    [playerItem setAudioMix:audioMix];
}

@end
