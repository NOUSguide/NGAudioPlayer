//
//  NGAudioPlayer.h
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

#import <Foundation/Foundation.h>
#import "NGWeak.h"
#import "NGAudioPlayerPlaybackState.h"
#import "NGAudioPlayerDelegate.h"
#import "NSURL+NGAudioPlayerNowPlayingInfo.h"


@interface NGAudioPlayer : NSObject

@property (nonatomic, assign) dispatch_queue_t delegate_queue;
@property (nonatomic, assign) id<NGAudioPlayerDelegate> delegate;
@property (nonatomic, readonly, getter = isPlaying) BOOL playing;
@property (nonatomic, readonly) NGAudioPlayerPlaybackState playbackState;
@property (nonatomic, readonly) NSURL *currentPlayingURL;
@property (nonatomic, readonly) NSTimeInterval durationOfCurrentPlayingURL;
@property (nonatomic, readonly) NSArray *enqueuedURLs;

/** Automatically updates MPNowPlayingInfoCenter with the dictionary associated with a given NSURL, defaults to YES */
@property (nonatomic, assign) BOOL automaticallyUpdateNowPlayingInfoCenter;

/** Uses media controls on Lock Screen and Multitasking Bar and responds to accessory's (i.e. headphones) remote controls, defaults to YES */
@property (nonatomic, assign) BOOL usesMediaControls;

/** Removes all URLs on playback-stop when YES and just stops playback and restarts current title when NO, defaults to NO */
@property (nonatomic, assign) BOOL removeAllURLsOnPlaybackStop;


/******************************************
 @name Class Methods
 ******************************************/

+ (BOOL)setAudioSessionCategory:(NSString *)audioSessionCategory;
+ (BOOL)initBackgroundAudio;

/******************************************
 @name Lifecycle
 ******************************************/

- (id)initWithURL:(NSURL *)url;
- (id)initWithURLs:(NSArray *)urls;

/******************************************
 @name Playback
 ******************************************/

/**
 This method removes all items from the queue and starts playing the given URL.
 
 @param url the URL to play
 */
- (void)playURL:(NSURL *)url;
- (void)play;
- (void)pause;
/**
 Pauses the player and removes all items from the queue.
 */
- (void)stop;
- (void)togglePlayback;

- (void)fadePlayerFromVolume:(CGFloat)fromVolume toVolume:(CGFloat)toVolume duration:(NSTimeInterval)duration;

/******************************************
 @name Queuing
 ******************************************/

/**
 This method adds the given URL to the end of the queue.
 
 @param url the URL to add to the queue
 @return YES if the URL was added successfully, NO otherwise
 */
- (BOOL)enqueueURL:(NSURL *)url;

/**
 This method adds the given URLs to the end of the queue.
 
 @param urls the URLs to add to the queue
 @return YES if all URLs were added successfully, NO otherwise
 */
- (BOOL)enqueueURLs:(NSArray *)urls;

/**
 This method adds the given AVPlayerItem to the end of the queue,
 it it's asset is an instance of AVURLAsset or a subclass of it.
 
 @param item the AVPlayerItem to add to the queue
 @return YES if the AVPlayerItem was added successfully, NO otherwise
 */
- (BOOL)enqueuePlayerItem:(AVPlayerItem *)item;

/**
 This method adds the given AVPlayerItems to the end of the queue,
 it it's asset is an instance of AVURLAsset or a subclass of it.
 
 @param urls the URLs to add to the queue
 @return YES if all URLs were added successfully, NO otherwise
 */
- (BOOL)enqueueItems:(NSArray *)item;

/******************************************
 @name Removing
 ******************************************/

/**
 Removes the item with the given URL from the player-queue.
 
 @param url the URL of the item to remove
 @return YES if an item was removed, NO otherwise
 */
- (BOOL)removeURL:(NSURL *)url;
- (void)removeAllURLs;

- (void)advanceToNextURL;

@end
