// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_expo_push/otel_expo_push.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_expo_push-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('push.send records ticket + platform + priority + ttl', () async {
    await tracedExpoPush<String>(
      operation: 'push.send',
      invoke: () async => const ExpoPushCallResult(
        value: 'ok',
        result: ExpoPushResult(
          ticketId: 'XXX-tickets-1',
          recipientPlatform: 'ios',
          channelId: 'default',
          priority: 'high',
          ttlSec: 3600,
          batchSize: 100,
          okCount: 98,
          errorCount: 2,
          status: 'ok',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('expo_push push.send')!);
    expect(a['expo_push.ticket.id'], 'XXX-tickets-1');
    expect(a['expo_push.recipient.platform'], 'ios');
    expect(a['expo_push.priority'], 'high');
    expect(a['expo_push.ttl_sec'], 3600);
    expect(a['expo_push.batch.ok_count'], 98);
    expect(a['expo_push.batch.error_count'], 2);
  });

  test('DeviceNotRegistered receipt sets span error', () async {
    await tracedExpoPush<String>(
      operation: 'push.getReceipts',
      invoke: () async => const ExpoPushCallResult(
        value: 'ok',
        result: ExpoPushResult(
          receiptId: 'r_1',
          status: 'error',
          errorCode: 'DeviceNotRegistered',
        ),
      ),
    );
    final s = spans.findSpanByName('expo_push push.getReceipts')!;
    expect(s.status, SpanStatusCode.Error);
    expect(attrsOf(s)['expo_push.error.code'], 'DeviceNotRegistered');
  });

  test('all-failed batch sets span error', () async {
    await tracedExpoPush<String>(
      operation: 'push.send',
      invoke: () async => const ExpoPushCallResult(
        value: 'ok',
        result: ExpoPushResult(
          batchSize: 50,
          okCount: 0,
          errorCount: 50,
        ),
      ),
    );
    expect(
      spans.findSpanByName('expo_push push.send')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutExpoPushInstrumentationAsync(() async {
      await tracedExpoPush<String>(
        operation: 'push.send',
        invoke: () async => const ExpoPushCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('expo_push '), isEmpty);
  });
}
