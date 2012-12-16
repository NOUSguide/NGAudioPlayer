//
//  NGAudioPlayerControlResponder.h
//  NGAudioPlayer
//
//  Created by Manfred Scheiner on 08.11.12.
//  Copyright (c) 2012 PocketScience GmbH. All rights reserved.
//

#import "NGAudioPlayer.h"

@interface NGAudioPlayerControlResponder : UIResponder

@property (nonatomic, strong) NGAudioPlayer *player;
@property (nonatomic, assign) BOOL respondingToControls;

- (id)initWithAudioPlayer:(NGAudioPlayer *)player;

@end
