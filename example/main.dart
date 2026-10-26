// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_expo_push/otel_expo_push.dart';

/// Traces Expo push calls with OpenTelemetry.
///
/// `otel_expo_push` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Expo push call in
/// [tracedExpoPush]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'expo-push-example');

  // Wraps an Expo push request in a CLIENT span.
  final expoPushId = await tracedExpoPush<String>(
    operation: 'push.send',
    invoke: () async {
      // Make the Expo push call here, then report what it returned.
      const id = 'expo_push_8f3a2c';
      return const ExpoPushCallResult(
          value: id,
          result: ExpoPushResult(
              ticketId: 'ticket_8f3a2c',
              receiptId: '/push/getReceipts',
              recipientPlatform: 'ios',
              channelId: 'channel_8f3a2c',
              priority: 'default',
              ttlSec: 1,
              batchSize: 512,
              okCount: 3,
              errorCount: 3,
              status: 'ok',
              errorCode: 'DeviceNotRegistered',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedExpoPush push.send returned $expoPushId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutExpoPushInstrumentationAsync.
  await runWithoutExpoPushInstrumentationAsync(
    () => tracedExpoPush<String>(
      operation: 'push.send',
      invoke: () async {
        const id = 'expo_push_8f3a2c';
        return const ExpoPushCallResult(
            value: id,
            result: ExpoPushResult(
                ticketId: 'ticket_8f3a2c',
                receiptId: '/push/getReceipts',
                recipientPlatform: 'ios',
                channelId: 'channel_8f3a2c',
                priority: 'default',
                ttlSec: 1,
                batchSize: 512,
                okCount: 3,
                errorCount: 3,
                status: 'ok',
                errorCode: 'DeviceNotRegistered',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
