// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.androidalarmmanager;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.PowerManager;

import androidx.legacy.content.WakefulBroadcastReceiver;

public class AlarmBroadcastReceiver extends WakefulBroadcastReceiver {
  private PowerManager.WakeLock screenWakeLock;
  /**
   * Invoked by the OS when a timer goes off.
   *
   * <p>The associated timer was registered in {@link AlarmService}.
   *
   * <p>In Android, timer notifications require a {@link BroadcastReceiver} as the artifact that is
   * notified when the timer goes off. As a result, this method is kept simple, immediately
   * offloading any work to {@link AlarmService#enqueueAlarmProcessing(Context, Intent)}.
   *
   * <p>This method is the beginning of an execution path that will eventually execute a desired
   * Dart callback function, as registed by the Dart side of the android_alarm_manager plugin.
   * However, there may be asynchronous gaps between {@code onReceive()} and the eventual invocation
   * of the Dart callback because {@link AlarmService} may need to spin up a Flutter execution
   * context before the callback can be invoked.
   */
  @Override
  public void onReceive(Context context, Intent intent) {
    if (screenWakeLock == null) {
      PowerManager pm = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
      screenWakeLock = pm.newWakeLock(PowerManager.SCREEN_DIM_WAKE_LOCK | PowerManager.ACQUIRE_CAUSES_WAKEUP, "mocha:event_trigger");
      screenWakeLock.acquire(61*60*1000L /*61 minutes*/);
    }

    AlarmService.enqueueAlarmProcessing(context, intent);

    if (screenWakeLock != null) {
      screenWakeLock.release();
    }
  }
}
