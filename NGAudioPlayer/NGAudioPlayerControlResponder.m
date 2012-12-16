//
//  NGAudioPlayerControlResponder.m
//  NGAudioPlayer
//
//  Created by Manfred Scheiner on 08.11.12.
//  Copyright (c) 2012 PocketScience GmbH. All rights reserved.
//

#import "NGAudioPlayerControlResponder.h"

@implementation NGAudioPlayerControlResponder

////////////////////////////////////////////////////////////////////////
#pragma mark - Lifecycle
////////////////////////////////////////////////////////////////////////

- (id)initWithAudioPlayer:(NGAudioPlayer *)player {
    self = [super init];
    if (self != nil) {
        self.player = player;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:NSSelectorFromString(@"remoteControlReceivedWithEvent:") name:@"remoteControlReceivedWithEvent" object:nil];
    }
    return self;
}

- (void)dealloc {
    self.respondingToControls = NO;
    self.player = nil;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - NGAudioPlayerResponder Properties
////////////////////////////////////////////////////////////////////////

- (void)setRespondingToControls:(BOOL)respondingToControls {
    if (respondingToControls) {
        if ([[UIApplication sharedApplication] respondsToSelector:NSSelectorFromString(@"remoteControlReceivedWithEvent:")]) {
            [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
            _respondingToControls = YES;
        }
        else {
            NSLog(@"NGAudioPlayerResponder couldn't be activated because AppDelegate doesn't respond to 'remoteControlReceivedWithEvent:'");
        }
    }
    else {
        [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
        _respondingToControls = NO;
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - NGAudioPlayer Properties
////////////////////////////////////////////////////////////////////////

- (void)remoteControlReceivedWithEvent:(NSNotification *)notification {
    UIEvent *receivedEvent = (UIEvent *)[notification object];
    if (receivedEvent.type == UIEventTypeRemoteControl) {
        switch (receivedEvent.subtype) {
            case UIEventSubtypeRemoteControlTogglePlayPause: {
                [self.player togglePlayback];
                break;
            }
            case UIEventSubtypeRemoteControlPreviousTrack: {
                break;
            }
            case UIEventSubtypeRemoteControlNextTrack: {
                break;
            }
            default: {
                break;
            }
        }
    }
}

@end
