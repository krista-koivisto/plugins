// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String _backgroundName =
    'plugins.flutter.io/android_alarm_manager_background';

// This is the entrypoint for the background isolate. Since we can only enter
// an isolate once, we setup a MethodChannel to listen for method invokations
// from the native portion of the plugin. This allows for the plugin to perform
// any necessary processing in Dart (e.g., populating a custom object) before
// invoking the provided callback.
void _alarmManagerCallbackDispatcher() {
  const MethodChannel _channel =
      MethodChannel(_backgroundName, JSONMethodCodec());

  // Setup Flutter state needed for MethodChannels.
  WidgetsFlutterBinding.ensureInitialized();

  // This is where the magic happens and we handle background events from the
  // native portion of the plugin.
  _channel.setMethodCallHandler((MethodCall call) async {
    final dynamic args = call.arguments;
    final CallbackHandle handle = CallbackHandle.fromRawHandle(args[0]);

    // PluginUtilities.getCallbackFromHandle performs a lookup based on the
    // callback handle and returns a tear-off of the original callback.
    final Function closure = PluginUtilities.getCallbackFromHandle(handle);

    if (closure == null) {
      print('Fatal: could not find callback');
      exit(-1);
    }

    if (closure is Function()) {
      closure();
    } else if (closure is Function(int)) {
      final int id = args[1];
      closure(id);
    }
  });

  // Once we've finished initializing, let the native portion of the plugin
  // know that it can start scheduling alarms.
  _channel.invokeMethod<void>('AlarmService.initialized');
}

/// A Flutter plugin for registering Dart callbacks with the Android
/// AlarmManager service.
///
/// See the example/ directory in this package for sample usage.
class AndroidAlarmManager {
  static const String _channelName = 'plugins.flutter.io/android_alarm_manager';
  static const MethodChannel _channel =
      MethodChannel(_channelName, JSONMethodCodec());

  /// Starts the [AndroidAlarmManager] service. This must be called before
  /// setting any alarms.
  ///
  /// Returns a [Future] that resolves to `true` on success and `false` on
  /// failure.
  static Future<bool> initialize() async {
    final CallbackHandle handle =
        PluginUtilities.getCallbackHandle(_alarmManagerCallbackDispatcher);
    if (handle == null) {
      return false;
    }
    final bool r = await _channel.invokeMethod<bool>(
        'AlarmService.start', <dynamic>[handle.toRawHandle()]);
    return r ?? false;
  }

  /// Schedules a one-shot timer to run `callback` after time `delay`.
  ///
  /// The `callback` will run whether or not the main application is running or
  /// in the foreground. It will run in the Isolate owned by the
  /// AndroidAlarmManager service.
  ///
  /// `callback` must be either a top-level function or a static method from a
  /// class.
  ///
  /// `callback` can be `Function()` or `Function(int)`
  ///
  /// The timer is uniquely identified by `id`. Calling this function again
  /// with the same `id` will cancel and replace the existing timer.
  ///
  /// `id` will passed to `callback` if it is of type `Function(int)`.
  ///
  /// If `alarmClock` is passed as `true`, the timer will be created with
  /// Android's `AlarmManagerCompat.setAlarmClock`.
  ///
  /// If `allowWhileIdle` is passed as `true`, the timer will be created with
  /// Android's `AlarmManagerCompat.setExactAndAllowWhileIdle` or
  /// `AlarmManagerCompat.setAndAllowWhileIdle`.
  ///
  /// If `exact` is passed as `true`, the timer will be created with Android's
  /// `AlarmManagerCompat.setExact`. When `exact` is `false` (the default), the
  /// timer will be created with `AlarmManager.set`.
  ///
  /// If `wakeup` is passed as `true`, the device will be woken up when the
  /// alarm fires. If `wakeup` is false (the default), the device will not be
  /// woken up to service the alarm.
  ///
  /// If `rescheduleOnReboot` is passed as `true`, the alarm will be persisted
  /// across reboots. If `rescheduleOnReboot` is false (the default), the alarm
  /// will not be rescheduled after a reboot and will not be executed.
  ///
  /// Returns a [Future] that resolves to `true` on success and `false` on
  /// failure.
  static Future<bool> oneShot(
    Duration delay,
    int id,
    Function callback, {
    bool alarmClock = false,
    bool allowWhileIdle = false,
    bool exact = false,
    bool wakeup = false,
    bool rescheduleOnReboot = false,
  }) =>
      oneShotAt(
        DateTime.now().add(delay),
        id,
        callback,
        alarmClock: alarmClock,
        allowWhileIdle: allowWhileIdle,
        exact: exact,
        wakeup: wakeup,
        rescheduleOnReboot: rescheduleOnReboot,
      );

  /// Schedules a one-shot timer to run `callback` at `time`.
  ///
  /// The `callback` will run whether or not the main application is running or
  /// in the foreground. It will run in the Isolate owned by the
  /// AndroidAlarmManager service.
  ///
  /// `callback` must be either a top-level function or a static method from a
  /// class.
  ///
  /// `callback` can be `Function()` or `Function(int)`
  ///
  /// The timer is uniquely identified by `id`. Calling this function again
  /// with the same `id` will cancel and replace the existing timer.
  ///
  /// `id` will passed to `callback` if it is of type `Function(int)`
  ///
  /// If `alarmClock` is passed as `true`, the timer will be created with
  /// Android's `AlarmManagerCompat.setAlarmClock`.
  ///
  /// If `allowWhileIdle` is passed as `true`, the timer will be created with
  /// Android's `AlarmManagerCompat.setExactAndAllowWhileIdle` or
  /// `AlarmManagerCompat.setAndAllowWhileIdle`.
  ///
  /// If `exact` is passed as `true`, the timer will be created with Android's
  /// `AlarmManagerCompat.setExact`. When `exact` is `false` (the default), the
  /// timer will be created with `AlarmManager.set`.
  ///
  /// If `wakeup` is passed as `true`, the device will be woken up when the
  /// alarm fires. If `wakeup` is false (the default), the device will not be
  /// woken up to service the alarm.
  ///
  /// If `rescheduleOnReboot` is passed as `true`, the alarm will be persisted
  /// across reboots. If `rescheduleOnReboot` is false (the default), the alarm
  /// will not be rescheduled after a reboot and will not be executed.
  ///
  /// Returns a [Future] that resolves to `true` on success and `false` on
  /// failure.
  static Future<bool> oneShotAt(
    DateTime time,
    int id,
    Function callback, {
    bool alarmClock = false,
    bool allowWhileIdle = false,
    bool exact = false,
    bool wakeup = false,
    bool rescheduleOnReboot = false,
  }) async {
    assert(callback is Function() || callback is Function(int));
    assert(id.bitLength < 32);
    final int startMillis = time.millisecondsSinceEpoch;
    final CallbackHandle handle = PluginUtilities.getCallbackHandle(callback);
    if (handle == null) {
      return false;
    }
    final bool r =
        await _channel.invokeMethod<bool>('Alarm.oneShotAt', <dynamic>[
      id,
      alarmClock,
      allowWhileIdle,
      exact,
      wakeup,
      startMillis,
      rescheduleOnReboot,
      handle.toRawHandle(),
    ]);
    return (r == null) ? false : r;
  }

  /// Schedules a repeating timer to run `callback` with period `duration`.
  ///
  /// The `callback` will run whether or not the main application is running or
  /// in the foreground. It will run in the Isolate owned by the
  /// AndroidAlarmManager service.
  ///
  /// `callback` must be either a top-level function or a static method from a
  /// class.
  ///
  /// `callback` can be `Function()` or `Function(int)`
  ///
  /// The repeating timer is uniquely identified by `id`. Calling this function
  /// again with the same `id` will cancel and replace the existing timer.
  ///
  /// `id` will passed to `callback` if it is of type `Function(int)`
  ///
  /// If `startAt` is passed, the timer will first go off at that time and
  /// subsequently run with period `duration`.
  ///
  /// If `exact` is passed as `true`, the timer will be created with Android's
  /// `AlarmManager.setRepeating`. When `exact` is `false` (the default), the
  /// timer will be created with `AlarmManager.setInexactRepeating`.
  ///
  /// If `wakeup` is passed as `true`, the device will be woken up when the
  /// alarm fires. If `wakeup` is false (the default), the device will not be
  /// woken up to service the alarm.
  ///
  /// If `rescheduleOnReboot` is passed as `true`, the alarm will be persisted
  /// across reboots. If `rescheduleOnReboot` is false (the default), the alarm
  /// will not be rescheduled after a reboot and will not be executed.
  ///
  /// Returns a [Future] that resolves to `true` on success and `false` on
  /// failure.
  static Future<bool> periodic(
    Duration duration,
    int id,
    Function callback, {
    DateTime startAt,
    bool exact = false,
    bool wakeup = false,
    bool rescheduleOnReboot = false,
  }) async {
    assert(callback is Function() || callback is Function(int));
    assert(id.bitLength < 32);
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int period = duration.inMilliseconds;
    final int first =
        startAt != null ? startAt.millisecondsSinceEpoch : now + period;
    final CallbackHandle handle = PluginUtilities.getCallbackHandle(callback);
    if (handle == null) {
      return false;
    }
    final bool r = await _channel.invokeMethod<bool>(
        'Alarm.periodic', <dynamic>[
      id,
      exact,
      wakeup,
      first,
      period,
      rescheduleOnReboot,
      handle.toRawHandle()
    ]);
    return (r == null) ? false : r;
  }

  /// Cancels a timer.
  ///
  /// If a timer has been scheduled with `id`, then this function will cancel
  /// it.
  ///
  /// Returns a [Future] that resolves to `true` on success and `false` on
  /// failure.
  static Future<bool> cancel(int id) async {
    final bool r =
        await _channel.invokeMethod<bool>('Alarm.cancel', <dynamic>[id]);
    return (r == null) ? false : r;
  }

  /// Checks whether a timer exists.
  ///
  /// If a timer has been scheduled with `id`, then this function will return
  /// true.
  ///
  /// Returns a [Future] that resolves to `true` if alarm exists and `false` if
  /// alarm does not exist.
  static Future<bool> exists(int id) async {
    return await _channel.invokeMethod<bool>('Alarm.exists', <dynamic>[id]);
  }

  /// Acquires a wake lock on the device.
  ///
  /// Keeps the device CPU awake for `milliseconds` or until [releaseWakeLock]
  /// is called.
  static Future<void> acquireWakeLock(int milliseconds) async {
    await _channel.invokeMethod<bool>('Alarm.acquireWakeLock', <dynamic>[milliseconds]);
  }

  /// Checks whether a wake lock is currently being held.
  ///
  /// Returns a [Future] that resolves to `true` if a wake lock is being held
  /// by this alarm manager and `false` otherwise.
  static Future<bool> hasWakeLock() async {
    return await _channel.invokeMethod<bool>('Alarm.hasWakeLock');
  }

  /// Releases a previously requested wake lock.
  ///
  /// Allows the device's CPU to go back to sleep on behalf of this alarm
  /// manager. Does not release wake locks by other alarm managers or other
  /// applications on the device.
  static Future<void> releaseWakeLock() async {
    await _channel.invokeMethod<bool>('Alarm.releaseWakeLock', <dynamic>[]);
  }
}
