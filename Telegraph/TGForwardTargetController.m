#import "TGForwardTargetController.h"

#import "TGDialogListController.h"
#import "TGTelegraphDialogListCompanion.h"
#import "TGContactsController.h"

#import "TGInterfaceManager.h"
#import "TGInterfaceAssets.h"

#import "TGDatabase.h"

#import "TGFont.h"
#import "TGImageUtils.h"
#import "TGBackdropView.h"

@interface TGForwardContactsController : TGContactsController

@property (nonatomic, strong) ASHandle *watcher;

@end

@implementation TGForwardContactsController

@synthesize watcher = _watcher;

- (void)singleUserSelected:(TGUser *)user
{
    [_watcher requestAction:@"userSelected" options:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", nil]];
}

@end

#pragma mark -

@interface TGForwardTargetController () <UIAlertViewDelegate>
{
    NSString *_confirmationFormat;
}

@property (nonatomic) bool blockMode;

@property (nonatomic, strong) UIView *toolbarContainerView;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;

@property (nonatomic, strong) TGDialogListController *dialogListController;
@property (nonatomic, strong) TGTelegraphDialogListCompanion *dialogListCompanion;
@property (nonatomic, strong) TGForwardContactsController *contactsController;

@property (nonatomic, strong) TGViewController *currentViewController;

@property (nonatomic, strong) id selectedTarget;

@property (nonatomic, strong) NSArray *forwardMessages;
@property (nonatomic, strong) NSArray *sendMessages;
@property (nonatomic, strong) NSURL *documentFileUrl;
@property (nonatomic, strong) NSArray *documentFileDescs;

@property (nonatomic, strong) UIAlertView *currentAlert;

@end

@implementation TGForwardTargetController

- (id)initWithForwardMessages:(NSArray *)forwardMessages sendMessages:(NSArray *)sendMessages
{
    self = [super init];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _confirmationPrefix = TGLocalized(@"Conversation.ForwardToPrefix");
        
        _dialogListCompanion = [[TGTelegraphDialogListCompanion alloc] init];
        _dialogListCompanion.forwardMode = true;
        _dialogListCompanion.conversatioSelectedWatcher = _actionHandle;
        _dialogListController = [[TGDialogListController alloc] initWithCompanion:_dialogListCompanion];
        _dialogListController.customParentViewController = self;
        _dialogListController.doNotHideSearchAutomatically = true;
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/dialoglist/(%d)", INT_MAX] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:25], @"limit", [NSNumber numberWithInt:INT_MAX], @"date", nil] watcher:_dialogListCompanion];
        
        _contactsController = [[TGForwardContactsController alloc] initWithContactsMode:TGContactsModeRegistered | TGContactsModeClearSelectionImmediately];
        _contactsController.watcher = _actionHandle;
        _contactsController.customParentViewController = self;
        
        _forwardMessages = forwardMessages;
        _sendMessages = sendMessages;
    }
    return self;
}

- (id)initWithSelectBlockTarget
{
    self = [super init];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _dialogListCompanion = [[TGTelegraphDialogListCompanion alloc] init];
        _dialogListCompanion.forwardMode = true;
        _dialogListCompanion.conversatioSelectedWatcher = _actionHandle;
        _dialogListController = [[TGDialogListController alloc] initWithCompanion:_dialogListCompanion];
        _dialogListController.customParentViewController = self;
        _dialogListController.doNotHideSearchAutomatically = true;
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/dialoglist/(%d)", INT_MAX] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:25], @"limit", [NSNumber numberWithInt:INT_MAX], @"date", nil] watcher:_dialogListCompanion];
        
        _contactsController = [[TGForwardContactsController alloc] initWithContactsMode:TGContactsModeRegistered | TGContactsModeClearSelectionImmediately];
        _contactsController.watcher = _actionHandle;
        _contactsController.customParentViewController = self;
        
        _confirmationPrefix = TGLocalized(@"BlockedUsers.BlockPrefix");
        _controllerTitle = TGLocalized(@"BlockedUsers.BlockTitle");
        _blockMode = true;
    }
    return self;
}

- (id)initWithDocumentFile:(NSURL *)fileUrl size:(int)size
{
    self = [super init];
    if (self != nil)
    {
        NSString *genericFormat = TGLocalized(@"Document.TargetConfirmationFormat");
        NSRange range = [genericFormat rangeOfString:@"{size}"];
        if (range.location != 0)
        {
            NSString *sizeString = nil;
            
            if (size < 1024)
                sizeString = [[NSString alloc] initWithFormat:@"%dB", size];
            else if (size < 1024 * 1024)
                sizeString = [[NSString alloc] initWithFormat:@"%dKB", size / 1024];
            else
                sizeString = [[NSString alloc] initWithFormat:@"%.2fMB", size / (1024.0f * 1024.0f)];
            
            genericFormat = [genericFormat stringByReplacingCharactersInRange:range withString:sizeString];
            
            NSRange targetRange = [genericFormat rangeOfString:@"{target}"];
            if (targetRange.location != NSNotFound)
                genericFormat = [genericFormat stringByReplacingCharactersInRange:targetRange withString:@"%@"];
            
            _confirmationFormat = genericFormat;
        }
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _confirmationPrefix = TGLocalized(@"Conversation.ForwardToPrefix");
        
        _dialogListCompanion = [[TGTelegraphDialogListCompanion alloc] init];
        _dialogListCompanion.forwardMode = true;
        _dialogListCompanion.showSecretInForwardMode = true;
        _dialogListCompanion.conversatioSelectedWatcher = _actionHandle;
        _dialogListController = [[TGDialogListController alloc] initWithCompanion:_dialogListCompanion];
        _dialogListController.customParentViewController = self;
        _dialogListController.doNotHideSearchAutomatically = true;
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/dialoglist/(%d)", INT_MAX] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:25], @"limit", [NSNumber numberWithInt:INT_MAX], @"date", nil] watcher:_dialogListCompanion];
        
        _contactsController = [[TGForwardContactsController alloc] initWithContactsMode:TGContactsModeRegistered | TGContactsModeClearSelectionImmediately];
        _contactsController.watcher = _actionHandle;
        _contactsController.customParentViewController = self;
        
        _documentFileUrl = fileUrl;
    }
    return self;
}

- (id)initWithDocumentFiles:(NSArray *)fileDescs
{
    self = [super init];
    if (self != nil)
    {
        NSString *genericFormat = TGLocalized(@"Document.TargetConfirmationFormat");
        NSRange range = [genericFormat rangeOfString:@"{size}"];
        if (range.location != 0)
        {
            NSString *sizeString = nil;
            
            int size = 1;
            
            if (size < 1024)
                sizeString = [[NSString alloc] initWithFormat:@"%dB", size];
            else if (size < 1024 * 1024)
                sizeString = [[NSString alloc] initWithFormat:@"%dKB", size / 1024];
            else
                sizeString = [[NSString alloc] initWithFormat:@"%.2fMB", size / (1024.0f * 1024.0f)];
            
            genericFormat = [genericFormat stringByReplacingCharactersInRange:range withString:sizeString];
            
            NSRange targetRange = [genericFormat rangeOfString:@"{target}"];
            if (targetRange.location != NSNotFound)
                genericFormat = [genericFormat stringByReplacingCharactersInRange:targetRange withString:@"%@"];
            
            _confirmationFormat = genericFormat;
        }
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _confirmationPrefix = TGLocalized(@"Conversation.ForwardToPrefix");
        
        _dialogListCompanion = [[TGTelegraphDialogListCompanion alloc] init];
        _dialogListCompanion.forwardMode = true;
        _dialogListCompanion.showSecretInForwardMode = true;
        _dialogListCompanion.conversatioSelectedWatcher = _actionHandle;
        _dialogListController = [[TGDialogListController alloc] initWithCompanion:_dialogListCompanion];
        _dialogListController.customParentViewController = self;
        _dialogListController.doNotHideSearchAutomatically = true;
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/dialoglist/(%d)", INT_MAX] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:25], @"limit", [NSNumber numberWithInt:INT_MAX], @"date", nil] watcher:_dialogListCompanion];
        
        _contactsController = [[TGForwardContactsController alloc] initWithContactsMode:TGContactsModeRegistered | TGContactsModeClearSelectionImmediately];
        _contactsController.watcher = _actionHandle;
        _contactsController.customParentViewController = self;
        
        _documentFileDescs = fileDescs;
    }
    return self;
}

- (void)dealloc
{
    [self doUnloadView];
    
    _currentAlert.delegate = nil;
    
    _dialogListController.customParentViewController = nil;
    _contactsController.customParentViewController = nil;
    
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (UIBarStyle)requiredNavigationBarStyle
{
    if (_currentViewController != nil && [_currentViewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance) ] && [_currentViewController respondsToSelector:@selector(requiredNavigationBarStyle)])
        return [(id<TGViewControllerNavigationBarAppearance>)_currentViewController requiredNavigationBarStyle];
    return UIBarStyleDefault;
}

- (bool)navigationBarShouldBeHidden
{
    if (_currentViewController != nil && [_currentViewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance) ] && [_currentViewController respondsToSelector:@selector(navigationBarShouldBeHidden)])
        return [(id<TGViewControllerNavigationBarAppearance>)_currentViewController navigationBarShouldBeHidden];
    return false;
}

- (bool)shouldBeRemovedFromNavigationAfterHiding
{
    return true;
}

- (void)loadView
{
    [super loadView];
    
    self.titleText = _controllerTitle != nil ? _controllerTitle : TGLocalized(@"Conversation.ForwardTitle");
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(doneButtonPressed)];
    
    _toolbarContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 44, self.view.frame.size.width, 44)];
    _toolbarContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

    if (TGBackdropEnabled())
    {
        UIView *backgroundView = [[UIToolbar alloc] initWithFrame:_toolbarContainerView.bounds];
        _toolbarContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_toolbarContainerView addSubview:backgroundView];
    }
    else
    {
        UIView *backgroundView = [TGBackdropView viewWithLightNavigationBarStyle];
        backgroundView.frame = _toolbarContainerView.bounds;
        backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_toolbarContainerView addSubview:backgroundView];
        
        UIView *stripeView = [[UIView alloc] init];
        stripeView.frame = CGRectMake(0.0f, 0.0f, _toolbarContainerView.frame.size.width, TGIsRetina() ? 0.5f : 1.0f);
        stripeView.backgroundColor = UIColorRGB(0xb2b2b2);
        stripeView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [_toolbarContainerView addSubview:stripeView];
    }
    
    _segmentedControl = [[UISegmentedControl alloc] initWithItems:@[TGLocalized(@"DialogList.TabTitle"), TGLocalized(@"Contacts.TabTitle")]];
    
    [_segmentedControl setBackgroundImage:[UIImage imageNamed:@"ModernSegmentedControlBackground.png"] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [_segmentedControl setBackgroundImage:[UIImage imageNamed:@"ModernSegmentedControlSelected.png"] forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
    [_segmentedControl setBackgroundImage:[UIImage imageNamed:@"ModernSegmentedControlSelected.png"] forState:UIControlStateSelected | UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
    [_segmentedControl setBackgroundImage:[UIImage imageNamed:@"ModernSegmentedControlHighlighted.png"] forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
    UIImage *dividerImage = [UIImage imageNamed:@"ModernSegmentedControlSeparator.png"];
    [_segmentedControl setDividerImage:dividerImage forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [_segmentedControl setDividerImage:dividerImage forLeftSegmentState:UIControlStateHighlighted rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [_segmentedControl setDividerImage:dividerImage forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
    
    _segmentedControl.frame = CGRectMake(floorf((_toolbarContainerView.frame.size.width - 182.0f) / 2), 8, 182.0f, 29.0f);
    _segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    
    [_segmentedControl setTitleTextAttributes:@{UITextAttributeTextColor: TGAccentColor(), UITextAttributeTextShadowColor: [UIColor clearColor], UITextAttributeFont: TGSystemFontOfSize(13)} forState:UIControlStateNormal];
    [_segmentedControl setTitleTextAttributes:@{UITextAttributeTextColor: [UIColor whiteColor], UITextAttributeTextShadowColor: [UIColor clearColor], UITextAttributeFont: TGSystemFontOfSize(13)} forState:UIControlStateSelected];
    
    [_segmentedControl setSelectedSegmentIndex:0];
    [_segmentedControl addTarget:self action:@selector(segmentedControlChanged) forControlEvents:UIControlEventValueChanged];
    
    [_toolbarContainerView addSubview:_segmentedControl];
    
    [self setCurrentViewController:_dialogListController];
    
    [self.view addSubview:_toolbarContainerView];
}

- (void)viewWillAppear:(BOOL)animated
{
    _toolbarContainerView.frame = CGRectMake(0, self.view.frame.size.height - 44, self.view.frame.size.width, 44);
    _segmentedControl.frame = CGRectMake(floorf((_toolbarContainerView.frame.size.width - 182.0f) / 2), 8, 182.0f, 29.0f);
    
    [super viewWillAppear:animated];
}

- (void)doUnloadView
{
    [self setCurrentViewController:nil];
    
    if (_dialogListController.isViewLoaded)
        _dialogListController.view = nil;
    if (_contactsController.isViewLoaded)
        _contactsController.view = nil;
}

- (void)setCurrentViewController:(TGViewController *)currentViewController
{
    if (_currentViewController != nil)
    {
        [_currentViewController willMoveToParentViewController:nil];
        [_currentViewController.view removeFromSuperview];
        [_currentViewController removeFromParentViewController];
        [_currentViewController didMoveToParentViewController:nil];
    }
    
    _currentViewController = currentViewController;
    
    if (_currentViewController != nil)
    {
        _currentViewController.parentInsets = UIEdgeInsetsMake(0, 0, _toolbarContainerView.frame.size.height, 0);
        
        [_currentViewController willMoveToParentViewController:self];
        [_currentViewController.view setFrame:self.view.bounds];
        [self.view insertSubview:_currentViewController.view atIndex:0];
        [self addChildViewController:_currentViewController];
        [_currentViewController didMoveToParentViewController:self];
    }
}

/*- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    _toolbarContainerView.frame = CGRectMake(0, self.view.frame.size.height - 44, self.view.frame.size.width, 44);
    if (_currentViewController != nil)
    {
        [_currentViewController.view setFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - _toolbarContainerView.frame.size.height)];
    }
}*/

#pragma mark -

- (void)doneButtonPressed
{
    [self dismissSelf];
}

- (void)dismissSelf
{
    [self.presentingViewController dismissViewControllerAnimated:true completion:nil];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    if (self.childViewControllers.count != 0)
        return [self.childViewControllers[0] preferredStatusBarStyle];
    
    return [super preferredStatusBarStyle];
}

- (void)segmentedControlChanged
{
    int index = _segmentedControl.selectedSegmentIndex;
    
    if (index == 0)
    {
        if (_currentViewController != _dialogListController)
            [self setCurrentViewController:_dialogListController];
    }
    else if (index == 1)
    {
        if (_currentViewController != _contactsController)
            [self setCurrentViewController:_contactsController];
    }
}

#pragma mark -

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)options
{
    if ([action isEqualToString:@"userSelected"])
    {
        TGUser *user = [options objectForKey:@"user"];
        if (user != nil)
        {
            if (_blockMode)
            {
                [_watcherHandle requestAction:@"blockUser" options:user];
            }
            else
            {
                _selectedTarget = user;
                
                _currentAlert.delegate = nil;
                
                NSString *alertText = nil;
                if (_confirmationFormat != nil)
                    alertText = [[NSString alloc] initWithFormat:_confirmationFormat, user.displayName];
                else
                    alertText = [NSString stringWithFormat:@"%@%@?", _confirmationPrefix, user.displayName];
                
                _currentAlert = [[UIAlertView alloc] initWithTitle:nil message:alertText delegate:self cancelButtonTitle:TGLocalized(@"Common.No") otherButtonTitles:TGLocalized(@"Common.Yes"), nil];
                [_currentAlert show];
            }
        }
    }
    else if ([action isEqualToString:@"conversationSelected"])
    {
        TGConversation *conversation = [options objectForKey:@"conversation"];
        if (conversation != nil)
        {
            _selectedTarget = conversation;
            
            if (conversation.isChat && conversation.conversationId > INT_MIN)
            {
                _selectedTarget = conversation;
                
                _currentAlert.delegate = nil;
                
                NSString *alertText = nil;
                if (_blockMode)
                    alertText = [NSString stringWithFormat:@"%@\"%@\"?", TGLocalized(@"BlockedUsers.LeavePrefix"), conversation.chatTitle];
                else if (_confirmationFormat != nil)
                    alertText = [[NSString alloc] initWithFormat:_confirmationFormat, conversation.chatTitle];
                else
                    alertText = [NSString stringWithFormat:@"%@\"%@\"?", _confirmationPrefix, conversation.chatTitle];
                
                _currentAlert = [[UIAlertView alloc] initWithTitle:nil message:alertText delegate:self cancelButtonTitle:TGLocalized(@"Common.No") otherButtonTitles:TGLocalized(@"Common.Yes"), nil];
                [_currentAlert show];
            }
            else
            {
                int uid = 0;
                
                if (conversation.isChat)
                {
                    if (conversation.chatParticipants.chatParticipantUids.count != 0)
                        uid = [conversation.chatParticipants.chatParticipantUids[0] intValue];
                }
                else
                    uid = (int)conversation.conversationId;
                
                TGUser *user = [TGDatabaseInstance() loadUser:uid];
                if (user != nil)
                {
                    if (_blockMode)
                    {
                        [_watcherHandle requestAction:@"blockUser" options:user];
                    }
                    else
                    {
                        _selectedTarget = conversation.isChat ? conversation : user;
                        
                        _currentAlert.delegate = nil;
                        
                        NSString *alertText = nil;
                        if (_confirmationFormat != nil)
                            alertText = [[NSString alloc] initWithFormat:_confirmationFormat, user.displayName];
                        else
                            alertText = [NSString stringWithFormat:@"%@%@?", _confirmationPrefix, user.displayName];
                        
                        _currentAlert = [[UIAlertView alloc] initWithTitle:nil message:alertText delegate:self cancelButtonTitle:TGLocalized(@"Common.No") otherButtonTitles:TGLocalized(@"Common.Yes"), nil];
                        [_currentAlert show];
                    }
                }
            }   
        }
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != alertView.cancelButtonIndex && _selectedTarget != nil)
    {
        if (_blockMode)
        {
            if ([_selectedTarget isKindOfClass:[TGUser class]])
                [_watcherHandle requestAction:@"blockUser" options:_selectedTarget];
            else if ([_selectedTarget isKindOfClass:[TGConversation class]])
                [_watcherHandle requestAction:@"leaveConversation" options:_selectedTarget];
        }
        else
        {
            id<ASWatcher> watcher = _watcherHandle.delegate;
            if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
                [watcher actionStageActionRequested:@"willForwardMessages" options:[[NSDictionary alloc] initWithObjectsAndKeys:self, @"controller", _selectedTarget, @"target", nil]];
            
            if (_documentFileDescs != nil)
            {
                if ([_selectedTarget isKindOfClass:[TGUser class]])
                {
                    TGUser *user = (TGUser *)_selectedTarget;
                    [[TGInterfaceManager instance] navigateToConversationWithId:user.uid conversation:nil performActions:@{@"forwardMessages": [NSArray arrayWithArray:_forwardMessages], @"sendFiles": _documentFileDescs} animated:false];
                }
                else if ([_selectedTarget isKindOfClass:[TGConversation class]])
                {
                    TGConversation *conversation = (TGConversation *)_selectedTarget;
                    [[TGInterfaceManager instance] navigateToConversationWithId:conversation.conversationId conversation:nil performActions:@{@"forwardMessages": [NSArray arrayWithArray:_forwardMessages], @"sendFiles": _documentFileDescs} animated:false];
                }
            }
            else
            {
                if ([_selectedTarget isKindOfClass:[TGUser class]])
                {
                    TGUser *user = (TGUser *)_selectedTarget;
                    [[TGInterfaceManager instance] navigateToConversationWithId:user.uid conversation:nil performActions:@{@"forwardMessages": [NSArray arrayWithArray:_forwardMessages], @"sendMessages": [NSArray arrayWithArray:_sendMessages], @"sendFiles": _documentFileUrl == nil ? @[] : @[@{@"url": _documentFileUrl}]} animated:false];
                }
                else if ([_selectedTarget isKindOfClass:[TGConversation class]])
                {
                    TGConversation *conversation = (TGConversation *)_selectedTarget;
                    [[TGInterfaceManager instance] navigateToConversationWithId:conversation.conversationId conversation:nil performActions:@{@"forwardMessages": [NSArray arrayWithArray:_forwardMessages], @"sendMessages": [NSArray arrayWithArray:_sendMessages], @"sendFiles": _documentFileUrl == nil ? @[] : @[@{@"url": _documentFileUrl}]} animated:false];
                }
            }
            
            if (watcher == nil)
                [self dismissSelf];
        }
    }
    
    _currentAlert.delegate = nil;
    _currentAlert = nil;
}

@end
