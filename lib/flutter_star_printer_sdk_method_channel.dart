import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_star_printer_sdk/flutter_star_printer_sdk_broadcast_listeners.dart';
import 'package:flutter_star_printer_sdk/models/connection_response.dart';
import 'package:flutter_star_printer_sdk/models/disconnect_response.dart';
import 'package:flutter_star_printer_sdk/models/enums.dart';
import 'package:flutter_star_printer_sdk/models/flutter_star_printer.dart';
import 'package:flutter_star_printer_sdk/models/star_printer_document.dart';
import 'package:flutter_star_printer_sdk/utils/utils.dart';

import 'flutter_star_printer_sdk_platform_interface.dart';

/// An implementation of [FlutterStarPrinterSdkPlatform] that uses method channels.
class MethodChannelFlutterStarPrinterSdk
    implements FlutterStarPrinterSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(
    'co.uk.ferns.flutter_plugins/flutter_star_printer_sdk',
  );

  final FlutterStarPrinterBroadcastListeners broadcastListeners =
      FlutterStarPrinterBroadcastListeners();

  MethodChannelFlutterStarPrinterSdk() {
    methodChannel.setMethodCallHandler((call) async {
      if (call.method == "onDiscovered") {
        final model = StarPrinterModel.fromName(
          Utils.snakeCaseToCamelCase(call.arguments['model']),
        );
        final identifier = call.arguments['identifier'] as String;
        final connection = StarConnectionInterface.fromName(
          call.arguments['connection'].toString().toLowerCase(),
        );

        final printer = FlutterStarPrinter(
          model: model,
          identifier: identifier,
          connection: connection,
        );

        broadcastListeners.whenDiscovered(printer);
      }
    });
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> discoverPrinter({
    required List<StarConnectionInterface> interfaces,
  }) async {
    await methodChannel.invokeMethod<String>('discoverPrinter',
        {"interfaces": interfaces.map((x) => x.name).toList()});
  }

  @override
  Future<void> printReceipt({
    required FlutterStarPrinter printer,
    required FlutterStarPrinterDocument document,
  }) async {
    try {
      await methodChannel.invokeMethod<bool>(
        'printDocument',
        {
          "interfaceType": printer.connection.name,
          "identifier": printer.identifier,
          "document": document.toMap(),
        },
      );
    } on PlatformException {
      throw "Invalid Operation";
    }
  }

  @override
  Future<ConnectionResponse> connectPrinter({
    required FlutterStarPrinter printer,
  }) async {
    try {
      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
        'connectPrinter',
        {
          "interfaceType": printer.connection.name,
          "identifier": printer.identifier,
        },
      );
      return ConnectionResponse(
        connected: (result?['connected'] as bool?) ?? false,
        error: result?['error'] as String?,
      );
    } on PlatformException catch (e) {
      return ConnectionResponse(connected: false, error: e.message);
    }
  }

  @override
  Future<DisconnectResponse> disconnectPrinter({
    required FlutterStarPrinter printer,
  }) async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'disconnectPrinter',
      {
        "interfaceType": printer.connection.name,
        "identifier": printer.identifier,
      },
    );
    return DisconnectResponse(
      disconnected: (result?['disconnected'] as bool?) ?? false,
      error: result?['error'] as String?,
    );
  }

  @override
  void resetDiscoveryResult() => broadcastListeners.reset();

  @override
  Future<bool> savePrinter(FlutterStarPrinter printer) async {
    try {
      final saved = await methodChannel.invokeMethod<bool?>(
        'savePrinter',
        {
          "connection": printer.connection.name,
          "identifier": printer.identifier,
          "model": printer.model.name,
        },
      );

      return saved ?? false;
    } on PlatformException {
      throw "Failed to save printer";
    }
  }

  @override
  Future<FlutterStarPrinter?> loadSavedPrinter() async {
    try {
      // Invoke the 'loadPrinter' method via the method channel to get printer configuration.
      final config = await methodChannel
          .invokeMethod<Map<Object?, Object?>>('loadPrinter');

      // If no configuration is available, return null.
      if (config == null) return null;

      // Extract printer model from the configuration.
      final model = StarPrinterModel.fromName(
        Utils.snakeCaseToCamelCase(config['model'] as String),
      );

      // Extract printer identifier from the configuration.
      final identifier = config['identifier'] as String;

      // Extract the connection type and convert it to the corresponding enum.
      final connection = StarConnectionInterface.fromName(
        config['connection'].toString().toLowerCase(),
      );

      // Create a FlutterStarPrinter instance using the extracted data.
      final printer = FlutterStarPrinter(
        model: model,
        identifier: identifier,
        connection: connection,
      );

      return printer;
    } on PlatformException {
      // Handle any exceptions that may occur during the loading process.
      throw "Failed to load printer settings";
    }
  }
}
