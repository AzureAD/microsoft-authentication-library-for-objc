//------------------------------------------------------------------------------
//
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSALTestAppAcquireLayoutBuilder.h"

@implementation MSALTestAppAcquireLayoutBuilder

- (id)init
{
    if (!(self = [super init]))
        return nil;
    
    _screenRect = UIScreen.mainScreen.bounds;
    _contentView = [[UIView alloc] initWithFrame:_screenRect];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    
    _views = [NSMutableDictionary new];
    _keys = [NSMutableArray new];
    
    return self;
}

- (void)addControl:(UIControl *)control
             title:(NSString *)title
{
    UIView* view = [[UIView alloc] init];
    UILabel* label = [[UILabel alloc] init];
    label.textColor = UIColor.blackColor;
    label.text = title;
    label.font = [UIFont systemFontOfSize:12.0];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textAlignment = NSTextAlignmentRight;
    
    [view addSubview:label];
    
    control.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:control];
    
    NSDictionary* views = @{ @"label" : label, @"control" : control };
    NSArray* verticalConstraints1 = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[label]|" options:0 metrics:NULL views:views];
    NSArray* verticalConstraints2 = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[control(29)]|" options:0 metrics:NULL views:views];
    NSArray* horizontalConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[label(100)]-[control]|" options:NSLayoutFormatAlignAllCenterY metrics:NULL views:views];
    
    [view addConstraints:verticalConstraints1];
    [view addConstraints:verticalConstraints2];
    [view addConstraints:horizontalConstraints];
    
    [self addView:view key:title];
}

- (void)addViewInternal:(UIView*)view key:(NSString *)key
{
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:view];
    [_views setObject:view forKey:key];
    [_keys addObject:key];
}

- (void)addView:(UIView*)view key:(NSString *)key
{
    [self addViewInternal:view key:key];
    
    NSString* horizontalConstraint = [NSString stringWithFormat:@"H:|-6-[%@]-6-|", key];
    NSArray* horizontalConstraints2 = [NSLayoutConstraint constraintsWithVisualFormat:horizontalConstraint options:0 metrics:NULL views:_views];
    [_contentView addConstraints:horizontalConstraints2];
}

- (void)addCenteredView:(UIView *)view key:(NSString *)key
{
    [self addViewInternal:view key:key];
    
    NSLayoutConstraint* centerConstraint =
    [NSLayoutConstraint constraintWithItem:view
                                 attribute:NSLayoutAttributeCenterX
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:_contentView
                                 attribute:NSLayoutAttributeCenterX
                                multiplier:1.0
                                  constant:0.0];
    [_contentView addConstraint:centerConstraint];
}

- (UIView*)contentView
{
    if (_keys.count == 0)
    {
        return _contentView;
    }
    
    NSMutableString* verticalConstraint = [NSMutableString new];
    [verticalConstraint appendString:@"V:|"];
    
    for (int i = 0; i < _keys.count - 1; i++)
    {
        NSString* key = _keys[i];
        [verticalConstraint appendFormat:@"[%@]-", key];
    }
    
    NSString* lastKey = _keys.lastObject;
    [verticalConstraint appendFormat:@"[%@(>=200)]-36-|", lastKey];
    
    NSArray* verticalConstraints = [NSLayoutConstraint constraintsWithVisualFormat:verticalConstraint options:0 metrics:NULL views:_views];
    [_contentView addConstraints:verticalConstraints];
    
    return _contentView;
}

@end
