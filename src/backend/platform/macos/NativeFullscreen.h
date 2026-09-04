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


#pragma once

#include <functional>

class QWindow;


namespace platform {
namespace macos {

/// If `window`'s underlying native NSWindow is currently in native
/// (Cocoa Spaces) fullscreen, asks it to exit and calls `on_exited` only
/// once macOS has confirmed the exit animation has genuinely completed
/// (the `NSWindowDidExitFullScreenNotification`), not merely requested.
///
/// If the window is null or isn't currently fullscreen, `on_exited` is
/// called immediately, synchronously.
///
/// This exists because Qt's own cross-platform fullscreen state tracking
/// (QWindow::visibility/visibilityChanged) is not reliable on macOS - see
/// QTBUG-33607 - and there is no portable way to know when the native,
/// asynchronous Spaces transition has actually finished. This uses the
/// NSWindowDelegate-equivalent notification that Apple documents as firing
/// only after the animation completes.
void exit_fullscreen_then(QWindow* window, std::function<void()> on_exited);

/// Forces this process to become the frontmost/active application right
/// now, instead of passively waiting for macOS to hand that back on its
/// own, and calls `on_active` only once macOS has confirmed activation is
/// genuinely complete (NSApplicationDidBecomeActiveNotification) - a bare
/// call to activate() is itself asynchronous, so creating a fullscreen
/// window right after calling it without waiting for confirmation can
/// still race it.
///
/// This matters after a game exits: Pegasus has zero windows open for the
/// entire time the game runs, and macOS does not automatically restore
/// activation to a windowless background process once the game quits - so
/// the very next window we create (which immediately wants native
/// fullscreen) would otherwise be created while we're still inactive, and
/// the fullscreen request would silently fail exactly like the launch-side
/// issue this mirrors.
///
/// If already active, `on_active` is called immediately, synchronously.
void activate_app_then(std::function<void()> on_active);

/// Checks `window`'s real native fullscreen state (not Qt's, which is not
/// reliable here - see exit_fullscreen_then) and, if it isn't fullscreen,
/// re-requests it and checks again, repeating a few times before giving up.
/// Calls `on_settled` once the window is confirmed fullscreen or the
/// attempts run out.
///
/// Use this right after creating a window that's supposed to come up
/// fullscreen (eg. on rebuild() after a game exits): Pegasus has zero
/// windows open for the entire time a game runs, and when it creates a new
/// one, that window can briefly become genuinely fullscreen and then get
/// silently knocked back out shortly after - a lingering side effect of
/// the just-exited game's own fullscreen Space still being torn down at
/// the WindowServer level, which we have no direct per-event notification
/// for (unlike our own window's transitions). Rather than trying to guess
/// how long that cleanup takes, this verifies the actual outcome and
/// retries if needed instead of waiting up front and hoping.
void ensure_fullscreen_sticks(QWindow* window, std::function<void()> on_settled);

} // namespace macos
} // namespace platform
