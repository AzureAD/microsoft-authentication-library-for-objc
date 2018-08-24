// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "XCUIElement+CrossPlat.h"

@implementation XCUIElement (CrossPlat)

- (void)msidTap
{
#if TARGET_OS_IPHONE
    [self tap];
#else
    [self click];
#endif
}

- (void)msidPasteText:(NSString *)text application:(XCUIApplication *)app
{
#if TARGET_OS_IPHONE
    [UIPasteboard generalPasteboard].string = text;
    [self doubleTap];
    [app.menuItems[@"Paste"] tap];
#else
    [[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [[NSPasteboard generalPasteboard] setString:text forType:NSStringPboardType];
    [self click];
    [self typeKey:@"v" modifierFlags:XCUIKeyModifierCommand];
#endif
}

- (void)selectTextWithApp:(XCUIApplication *)app
{
#if TARGET_OS_IPHONE
    // There is a bug when we test in iOS 11 when emailTextField.value return placeholder value
    // instead of empty string. In order to make it work we check that value of text field is not
    // equal to placeholder.
    // See here: https://forums.developer.apple.com/thread/86653
    if (![self.placeholderValue isEqualToString:self.value] && self.value)
    {
        [self pressForDuration:0.5];
        [app.menuItems[@"Select All"] tap];
    }
#else
    [self typeKey:@"a" modifierFlags:XCUIKeyModifierCommand];
#endif
}

- (void)activateTextField
{
#if !TARGET_OS_IPHONE
    [self click];
#endif
}

@end
