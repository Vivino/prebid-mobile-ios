/*   Copyright 2019-2022 Prebid.org, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "MAXVideoRewardedViewController.h"
#import "PrebidDemoMacros.h"

NSString * const storedResponseVideoRewardedMAX = @"response-prebid-video-rewarded-320-480";
NSString * const storedImpVideoRewardedMAX = @"imp-prebid-video-rewarded-320-480";
NSString * const maxAdUnitRewardedId = @"75edc39e22574a9d";

@interface MAXVideoRewardedViewController ()

// Prebid
@property (nonatomic) MediationRewardedAdUnit * maxRewardedAdUnit;
@property (nonatomic) MAXMediationRewardedUtils * mediationDelegate;

// MAX
@property (nonatomic) MARewardedAd * maxRewarded;

@end

@implementation MAXVideoRewardedViewController

- (void)loadView {
    [super loadView];
    
    Prebid.shared.storedAuctionResponse = storedResponseVideoRewardedMAX;
    [self createAd];
}

- (void)createAd {
    // Setup integration kind - AppLovin MAX
    self.maxRewarded = [MARewardedAd sharedWithAdUnitIdentifier:maxAdUnitRewardedId];
    
    // Setup Prebid mediation ad unit
    self.mediationDelegate = [[MAXMediationRewardedUtils alloc] initWithRewardedAd:self.maxRewarded];
    self.maxRewardedAdUnit = [[MediationRewardedAdUnit alloc] initWithConfigId:storedImpVideoRewardedMAX mediationDelegate:self.mediationDelegate];
    
    // Setup Prebid mediation ad unit
    @weakify(self);
    [self.maxRewardedAdUnit fetchDemandWithCompletion:^(enum ResultCode resultCode) {
        @strongify(self);
        self.maxRewarded.delegate = self;
        [self.maxRewarded loadAd];
    }];
}

// MARK: - MARewardedAdDelegate

- (void)didLoadAd:(MAAd *)ad {
    if (self.maxRewarded != nil && self.maxRewarded.isReady) {
        [self.maxRewarded showAd];
    }
}

- (void)didFailToDisplayAd:(MAAd *)ad withError:(MAError *)error {
    PBMLogError(@"%@", error.message);
}

- (void)didFailToLoadAdForAdUnitIdentifier:(NSString *)adUnitIdentifier withError:(MAError *)error {
    PBMLogError(@"%@", error.message);
}

- (void)didDisplayAd:(MAAd *)ad {
}

- (void)didHideAd:(MAAd *)ad {
}

- (void)didClickAd:(MAAd *)ad {
}

- (void)didStartRewardedVideoForAd:(MAAd *)ad {
    // This delegate is not supported.
}

- (void)didCompleteRewardedVideoForAd:(MAAd *)ad {
    // This delegate is not supported.
}

- (void)didRewardUserForAd:(MAAd *)ad withReward:(MAReward *)reward {
}

@end
