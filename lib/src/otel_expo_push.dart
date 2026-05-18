// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_expo_push_suppression.dart';

const _tracerName = 'dartastic_otel_libs_expo_push';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class ExpoPushResult {
  const ExpoPushResult({
    this.ticketId,
    this.receiptId,
    this.recipientPlatform,
    this.channelId,
    this.priority,
    this.ttlSec,
    this.batchSize,
    this.okCount,
    this.errorCount,
    this.status,
    this.errorCode,
    this.statusCode,
  });

  /// Ticket id returned for a successful send (Expo queues, then
  /// delivers via APNs/FCM).
  final String? ticketId;

  /// Receipt id used to poll final delivery status from
  /// `/push/getReceipts`.
  final String? receiptId;

  /// `ios` / `android` — inferred from token prefix.
  final String? recipientPlatform;

  /// Android notification channel id.
  final String? channelId;

  /// `default` (5/normal) / `normal` / `high` — maps to APNs 10/5 and
  /// FCM high/normal.
  final String? priority;

  /// Time-to-live in seconds (0 = drop if offline).
  final int? ttlSec;

  /// Total messages in this batch request.
  final int? batchSize;

  /// Per-batch breakdown.
  final int? okCount;
  final int? errorCount;

  /// Ticket / receipt status: `ok` / `error`.
  final String? status;

  /// `DeviceNotRegistered` / `MessageTooBig` / `MessageRateExceeded` /
  /// `InvalidCredentials` / `MismatchSenderId` /
  /// `ExpoError`.
  final String? errorCode;

  final int? statusCode;
}

class ExpoPushCallResult<T> {
  const ExpoPushCallResult({required this.value, this.result});
  final T value;
  final ExpoPushResult? result;
}

/// Wraps an Expo push request in a CLIENT span. [operation] is one
/// of `push.send`, `push.getReceipts`.
Future<T> tracedExpoPush<T>({
  required String operation,
  required Future<ExpoPushCallResult<T>> Function() invoke,
}) async {
  if (expoPushInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'expo_push',
    'rpc.method': operation,
    'expo_push.operation': operation,
  };

  final span = _tracer().startSpan(
    'expo_push $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.ticketId != null) {
        extras.add(OTel.attributeString(
          'expo_push.ticket.id',
          r.result!.ticketId!,
        ));
      }
      if (r.result!.receiptId != null) {
        extras.add(OTel.attributeString(
          'expo_push.receipt.id',
          r.result!.receiptId!,
        ));
      }
      if (r.result!.recipientPlatform != null) {
        extras.add(OTel.attributeString(
          'expo_push.recipient.platform',
          r.result!.recipientPlatform!,
        ));
      }
      if (r.result!.channelId != null) {
        extras.add(OTel.attributeString(
          'expo_push.channel.id',
          r.result!.channelId!,
        ));
      }
      if (r.result!.priority != null) {
        extras.add(OTel.attributeString(
          'expo_push.priority',
          r.result!.priority!,
        ));
      }
      if (r.result!.ttlSec != null) {
        extras.add(OTel.attributeInt(
          'expo_push.ttl_sec',
          r.result!.ttlSec!,
        ));
      }
      if (r.result!.batchSize != null) {
        extras.add(OTel.attributeInt(
          'expo_push.batch.size',
          r.result!.batchSize!,
        ));
      }
      if (r.result!.okCount != null) {
        extras.add(OTel.attributeInt(
          'expo_push.batch.ok_count',
          r.result!.okCount!,
        ));
      }
      if (r.result!.errorCount != null) {
        extras.add(OTel.attributeInt(
          'expo_push.batch.error_count',
          r.result!.errorCount!,
        ));
        if (r.result!.errorCount! > 0 &&
            r.result!.okCount != null &&
            r.result!.okCount == 0) {
          span.setStatus(
            SpanStatusCode.Error,
            'Expo push batch all-failed',
          );
        }
      }
      if (r.result!.status != null) {
        extras.add(OTel.attributeString(
          'expo_push.status',
          r.result!.status!,
        ));
        if (r.result!.status == 'error') {
          span.setStatus(
            SpanStatusCode.Error,
            'Expo push status=error',
          );
        }
      }
      if (r.result!.errorCode != null) {
        extras.add(OTel.attributeString(
          'expo_push.error.code',
          r.result!.errorCode!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Expo Push HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
