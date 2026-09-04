// Pegasus Frontend
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.


#include "NativeFullscreen.h"

#import <Cocoa/Cocoa.h>

#include <QWindow>


namespace platform {
namespace macos {

void exit_fullscreen_then(QWindow* window, std::function<void()> on_exited)
{
    if (!window) {
        on_exited();
        return;
    }

    NSView* const view = reinterpret_cast<NSView*>(window->winId());
    NSWindow* const nswindow = view ? [view window] : nil;

    if (!nswindow || !(nswindow.styleMask & NSWindowStyleMaskFullScreen)) {
        // Not fullscreen (or no native window yet) - nothing to wait for.
        on_exited();
        return;
    }

    // Observe (not replace) the window's notifications - QCocoaWindow
    // already owns the NSWindowDelegate internally, so we must not touch
    // that. NSNotificationCenter supports any number of independent
    // observers on the same window without interfering with it.
    __block id token = nil;
    token = [[NSNotificationCenter defaultCenter]
        addObserverForName:NSWindowDidExitFullScreenNotification
                    object:nswindow
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification* note) {
            (void)note;
            [[NSNotificationCenter defaultCenter] removeObserver:token];
            on_exited();
        }];

    [nswindow toggleFullScreen:nil];
}

void activate_app_then(std::function<void()> on_active)
{
    // NOTE: deliberately not short-circuiting on NSApp.active here. That
    // flag is this process's own belief about its state, updated only by
    // notifications it has actually received - after running windowless
    // for an entire game session, it can be stale (still true from before)
    // even though the WindowServer does not currently consider us key/
    // frontmost. Always force + confirm instead of trusting it.
    __block BOOL already_called = NO;
    __block id token = nil;

    void (^call_once)() = ^{
        if (already_called)
            return;
        already_called = YES;
        if (token)
            [[NSNotificationCenter defaultCenter] removeObserver:token];
        on_active();
    };

    token = [[NSNotificationCenter defaultCenter]
        addObserverForName:NSApplicationDidBecomeActiveNotification
                    object:NSApp
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification* note) {
            (void)note;
            call_once();
        }];

    // -[NSApplication activate] (macOS 14+, matches this app's minimum
    // deployment target) requests genuine frontmost/active status
    // regardless of how this process was launched or what currently has
    // focus - but the request itself is asynchronous, hence waiting for
    // the notification above rather than proceeding right after this call.
    [NSApp activate];

    // Safety net: don't leave the frontend torn down forever if activation
    // is (unexpectedly) never reported.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                    dispatch_get_main_queue(), call_once);
}

void ensure_fullscreen_sticks(QWindow* window, std::function<void()> on_settled)
{
    if (!window) {
        on_settled();
        return;
    }

    NSView* const view = reinterpret_cast<NSView*>(window->winId());
    NSWindow* const nswindow = view ? [view window] : nil;
    if (!nswindow) {
        on_settled();
        return;
    }

    const bool initially_fullscreen = (nswindow.styleMask & NSWindowStyleMaskFullScreen) != 0;
    if (!initially_fullscreen) {
        // It was never fullscreen to begin with (eg. the user has the
        // fullscreen setting off) - nothing of ours to preserve, and we
        // must not force a state the window never asked for.
        on_settled();
        return;
    }

    // It *was* fullscreen; a dying game's own fullscreen Space can still be
    // mid-teardown at the WindowServer level for a bit after the process
    // itself has exited, and that can silently knock a freshly (re)created
    // fullscreen window of ours back out - sometime after appearing
    // genuinely fullscreen, not necessarily right away. There's no direct
    // per-event notification for when that foreign cleanup finishes, so
    // rather than guessing how long to wait up front, check the real
    // outcome and re-request fullscreen if it slipped. A single "looks
    // fullscreen right now" check isn't trustworthy either - that's exactly
    // how this looked before it got silently knocked back out - so two
    // consecutive fullscreen checks, spaced apart, are required before
    // declaring it actually stuck.
    // NOTE: a self-rescheduling block like this must be created with
    // dispatch_block_create (not a plain `^{ ... }` literal assigned to a
    // __block variable) - this file isn't compiled with ARC, and a raw
    // block that captures and re-submits itself via a __block reference
    // has no guarantee anything keeps its heap copy alive between the
    // async hops. dispatch_block_create's result is a proper dispatch
    // object GCD manages correctly for exactly this pattern.
    __block int attempts_left = 6;
    __block int consecutive_ok = 0;
    __block dispatch_block_t check_block = nil;
    check_block = dispatch_block_create((dispatch_block_flags_t)0, ^{
        const bool is_fullscreen = (nswindow.styleMask & NSWindowStyleMaskFullScreen) != 0;

        if (is_fullscreen) {
            ++consecutive_ok;
            if (consecutive_ok >= 2) {
                on_settled();
                return;
            }
            // Looks fullscreen, but confirm it's still true a bit later
            // before trusting it - don't re-toggle, it's already there.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                            dispatch_get_main_queue(), check_block);
            return;
        }

        consecutive_ok = 0;
        if (attempts_left <= 0) {
            on_settled();
            return;
        }

        --attempts_left;
        [nswindow toggleFullScreen:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                        dispatch_get_main_queue(), check_block);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                    dispatch_get_main_queue(), check_block);
}

} // namespace macos
} // namespace platform
