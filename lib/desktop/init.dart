/*
 * Copyright (C) 2022-2023 Yubico.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:platform_util/platform_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../app/app.dart';
import '../app/logging.dart';
import '../app/message.dart';
import '../app/views/app_failure_page.dart';
import '../app/views/main_page.dart';
import '../app/views/message_page.dart';
import '../core/state.dart';
import '../fido/state.dart';
import '../oath/state.dart';
import '../app/models.dart';
import '../app/state.dart';
import '../management/state.dart';
import '../version.dart';
import 'fido/state.dart';
import 'management/state.dart';
import 'oath/state.dart';
import 'rpc.dart';
import 'devices.dart';
import 'qr_scanner.dart';
import 'state.dart';

final _log = Logger('desktop.init');
const String _keyWidth = 'DESKTOP_WINDOW_WIDTH';
const String _keyHeight = 'DESKTOP_WINDOW_HEIGHT';
const String _keyPosDisplay = 'DESKTOP_WINDOW_POS_DISPLAY';
const String _keyPosX = 'DESKTOP_WINDOW_POS_X';
const String _keyPosY = 'DESKTOP_WINDOW_POS_Y';
const String _keyPrimaryScaleFactor = 'DESKTOP_PRIMARY_SCALE_FACTOR';

class _WindowManagerListener extends WindowListener {
  final SharedPreferences _prefs;

  _WindowManagerListener(this._prefs);

  @override
  void onWindowResize() async {
    windowMovedOrResized();
  }

  @override
  void onWindowMoved() async {
    windowMovedOrResized();
  }

  void windowsOnWindowMovedOrResized() async {
    final windowRect = await platformUtil.getWindowRect();
    final primaryDisplay = await screenRetriever.getPrimaryDisplay();

    final dpi = window.devicePixelRatio * 96.0;

    final double pdFactor = primaryDisplay.scaleFactor?.toDouble() ?? 1.0;
    final double pWidth = windowRect.width * pdFactor / window.devicePixelRatio;
    final double pHeight =
        windowRect.height * pdFactor / window.devicePixelRatio;

    _log.debug(
        'Persisting window bounds [${windowRect.left.toInt()},${windowRect.top.toInt()};${pWidth.toInt()}x${pHeight.toInt()}] windowDpi=$dpi windowScaleFactor=${window.devicePixelRatio}');
    await _prefs.setDouble(_keyPosX, windowRect.left);
    await _prefs.setDouble(_keyPosY, windowRect.top);
    await _prefs.setDouble(_keyWidth, pWidth);
    await _prefs.setDouble(_keyHeight, pHeight);
    await _prefs.setDouble(_keyPrimaryScaleFactor, pdFactor);
  }

  void windowMovedOrResized() async {
    if (Platform.isWindows) {
      windowsOnWindowMovedOrResized();
    } else {
      macOsOnWindowMovedOrResized();
    }
  }

  void macOsOnWindowMovedOrResized() async {
    final size = await windowManager.getSize();
    final offset = await windowManager.getPosition();
    final displays = await screenRetriever.getAllDisplays();

    for (var d in displays) {
      if (d.visiblePosition != null &&
          d.visibleSize != null &&
          d.name != null) {
        final windowCenter =
            Offset(offset.dx + size.width / 2.0, offset.dy + size.height / 2.0);
        if ((windowCenter.dx >= d.visiblePosition!.dx) &&
            (windowCenter.dx <
                (d.visiblePosition!.dx + d.visibleSize!.width)) &&
            (windowCenter.dy >= d.visiblePosition!.dy) &&
            (windowCenter.dy <
                (d.visiblePosition!.dy + d.visibleSize!.height))) {
          final localOffset = Offset(offset.dx - d.visiblePosition!.dx,
              offset.dy - d.visiblePosition!.dy);
          _log.debug(
              'Window moved to ${d.name}: global offset = $offset / local offset = $localOffset');
          await _prefs.setString(_keyPosDisplay, d.name!);
          await _prefs.setDouble(_keyPosX, localOffset.dx);
          await _prefs.setDouble(_keyPosY, localOffset.dy);
          await _prefs.setDouble(_keyWidth, size.width);
          await _prefs.setDouble(_keyHeight, size.height);
        }
      }
    }
  }
}

void windowsInitialize(SharedPreferences prefs) async {
  await platformUtil.init();
  await windowManager.setMinimumSize(const Size(270, 0));
  final primaryDisplay = await screenRetriever.getPrimaryDisplay();
  final double primaryScaleFactor =
      primaryDisplay.scaleFactor?.toDouble() ?? 1.0;

  final width = prefs.getDouble(_keyWidth) ?? 400;
  final height = prefs.getDouble(_keyHeight) ?? 720;
  final posX = prefs.getDouble(_keyPosX) ?? 0.0;
  final posY = prefs.getDouble(_keyPosY) ?? 0.0;
  final savedPrimaryScaleFactor =
      prefs.getDouble(_keyPrimaryScaleFactor) ?? 1.0;

  _log.debug(
      'Initializing window from persisted data at [${posX.toInt()},${posY.toInt()}:${width.toInt()}x${height.toInt()}]');
  final windowRect = Rect.fromLTWH(
    posX,
    posY,
    width / savedPrimaryScaleFactor * primaryScaleFactor,
    height / savedPrimaryScaleFactor * primaryScaleFactor,
  );
  await platformUtil.setWindowRect(windowRect);
  await windowManager.show();
}

void macOsInitialize(SharedPreferences prefs) async {
  await windowManager.setMinimumSize(const Size(270, 0));

  final width = prefs.getDouble(_keyWidth) ?? 400;
  final height = prefs.getDouble(_keyHeight) ?? 720;

  final posDisplay = prefs.getString(_keyPosDisplay);
  final posX = prefs.getDouble(_keyPosX);
  final posY = prefs.getDouble(_keyPosY);

  _log.debug('Target display: $posDisplay');

  if (posDisplay != null && posX != null && posY != null) {
    final displays = await screenRetriever.getAllDisplays();
    for (var d in displays) {
      if (d.name == posDisplay) {
        _log.debug(
            'Target display properties: ${d.id} ${d.name} ${d.visiblePosition} ${d.visibleSize} ${d.scaleFactor} ${d.size}');

        var globalPos =
            Offset(10 + d.visiblePosition!.dx, 10 + d.visiblePosition!.dy);
        if ((posX >= 0) &&
            (posX < d.visibleSize!.width) &&
            (posY >= 0) &&
            (posY < d.visibleSize!.height)) {
          // if the local position exists on the display, use it
          globalPos = Offset(
              posX + d.visiblePosition!.dx, posY + d.visiblePosition!.dy);
        }

        _log.debug(
            'Setting window to ${d.name} on local pos $posX, $posY, global: $globalPos');
        await windowManager.setBounds(null,
            size: Size(width, height),
            position: Offset(globalPos.dx, globalPos.dy));
      }
    }
  }

  await windowManager.show();
}

Future<Widget> initialize(List<String> argv) async {
  _initLogging(argv);

  await windowManager.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  unawaited(windowManager.waitUntilReadyToShow().then((_) async {
    if (Platform.isWindows) {
      windowsInitialize(prefs);
    } else {
      macOsInitialize(prefs);
    }
    windowManager.addListener(_WindowManagerListener(prefs));
  }));

  // Either use the _HELPER_PATH environment variable, or look relative to executable.
  var exe = Platform.environment['_HELPER_PATH'];
  if (exe?.isEmpty ?? true) {
    var relativePath = 'helper/authenticator-helper';
    if (Platform.isMacOS) {
      relativePath = '../Resources/$relativePath';
    } else if (Platform.isWindows) {
      relativePath += '.exe';
    }
    exe = Uri.file(Platform.resolvedExecutable)
        .resolve(relativePath)
        .toFilePath();

    if (Platform.isMacOS && Platform.version.contains('arm64')) {
      // See if there is an arm64 specific helper on arm64 Mac.
      final arm64exe = Uri.file(exe)
          .resolve('../helper-arm64/authenticator-helper')
          .toFilePath();
      if (await File(arm64exe).exists()) {
        exe = arm64exe;
      }
    }
  }

  final rpcFuture = _initHelper(exe!);
  _initLicenses();

  return ProviderScope(
    overrides: [
      supportedAppsProvider.overrideWithValue([
        Application.oath,
        Application.fido,
        Application.management,
      ]),
      prefProvider.overrideWithValue(prefs),
      rpcProvider.overrideWith((_) => rpcFuture),
      windowStateProvider.overrideWith(
        (ref) => ref.watch(desktopWindowStateProvider),
      ),
      attachedDevicesProvider.overrideWith(
        () => DesktopDevicesNotifier(),
      ),
      currentDeviceProvider.overrideWith(
        () => DesktopCurrentDeviceNotifier(),
      ),
      currentDeviceDataProvider.overrideWith(
        (ref) => ref.watch(desktopDeviceDataProvider),
      ),
      // OATH
      oathStateProvider.overrideWithProvider(desktopOathState),
      credentialListProvider
          .overrideWithProvider(desktopOathCredentialListProvider),
      qrScannerProvider.overrideWith(
        (ref) => ref.watch(desktopQrScannerProvider),
      ),
      // Management
      managementStateProvider.overrideWithProvider(desktopManagementState),
      // FIDO
      fidoStateProvider.overrideWithProvider(desktopFidoState),
      fingerprintProvider.overrideWithProvider(desktopFingerprintProvider),
      credentialProvider.overrideWithProvider(desktopCredentialProvider),
      clipboardProvider.overrideWith(
        (ref) => ref.watch(desktopClipboardProvider),
      ),
      supportedThemesProvider.overrideWith(
        (ref) => ref.watch(desktopSupportedThemesProvider),
      )
    ],
    child: YubicoAuthenticatorApp(
      page: Consumer(
        builder: ((context, ref, child) {
          // keep RPC log level in sync with app
          ref.listen<Level>(logLevelProvider, (_, level) {
            ref.read(rpcProvider).valueOrNull?.setLogLevel(level);
          });

          // Show a loading or error page while the Helper isn't ready
          return ref.watch(rpcProvider).when(
                data: (data) => const MainPage(),
                error: (error, stackTrace) => AppFailurePage(cause: error),
                loading: () => _HelperWaiter(),
              );
        }),
      ),
    ),
  );
}

Future<RpcSession> _initHelper(String exe) async {
  _log.info('Starting Helper subprocess: $exe');
  final rpc = RpcSession(exe);
  await rpc.initialize();
  _log.info('Helper process started');
  await rpc.setLogLevel(Logger.root.level);
  _log.info('Helper log level set');
  return rpc;
}

void _initLogging(List<String> argv) {
  Logger.root.onRecord.listen((record) {
    stderr.writeln(
        '${record.time.logFormat} [${record.loggerName}] ${record.level}: ${record.message}');
    if (record.error != null) {
      stderr.writeln(record.error);
    }
  });

  final logLevelIndex = argv.indexOf('--log-level');
  if (logLevelIndex != -1) {
    try {
      final levelName = argv[logLevelIndex + 1];
      Level level = Levels.LEVELS
          .firstWhere((level) => level.name == levelName.toUpperCase());
      Logger.root.level = level;
      _log.info('Log level initialized from command line argument');
    } catch (error) {
      _log.error('Failed to set log level', error);
    }
  }

  _log.info('Logging initialized, outputting to stderr');
}

void _initLicenses() async {
  LicenseRegistry.addLicense(() async* {
    final python =
        await rootBundle.loadString('assets/licenses/raw/python.txt');
    yield LicenseEntryWithLineBreaks(['Python'], python);

    final zxingcpp =
        await rootBundle.loadString('assets/licenses/raw/apache-2.0.txt');
    yield LicenseEntryWithLineBreaks(['zxing-cpp'], zxingcpp);

    final helper = await rootBundle.loadStructuredData<List>(
      'assets/licenses/helper.json',
      (value) async => jsonDecode(value),
    );

    for (final e in helper) {
      yield LicenseEntryWithLineBreaks([e['Name']], e['LicenseText']);
    }
  });
}

class _HelperWaiter extends ConsumerStatefulWidget {
  @override
  ConsumerState<_HelperWaiter> createState() => _HelperWaiterState();
}

class _HelperWaiterState extends ConsumerState<_HelperWaiter> {
  bool slow = false;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 10), () {
      setState(() {
        slow = true;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (slow) {
      return MessagePage(
        graphic: const CircularProgressIndicator(),
        message: 'The Helper process isn\'t responding',
        actions: [
          ActionChip(
            avatar: const Icon(Icons.copy),
            label: Text(AppLocalizations.of(context)!.general_copy_log),
            onPressed: () async {
              _log.info('Copying log to clipboard ($version)...');
              final logs = await ref.read(logLevelProvider.notifier).getLogs();
              var clipboard = ref.read(clipboardProvider);
              await clipboard.setText(logs.join('\n'));
              if (!clipboard.platformGivesFeedback()) {
                await ref.read(withContextProvider)(
                  (context) async {
                    showMessage(
                      context,
                      AppLocalizations.of(context)!.general_log_copied,
                    );
                  },
                );
              }
            },
          ),
        ],
      );
    } else {
      return const MessagePage(
        delayedContent: true,
        graphic: CircularProgressIndicator(),
      );
    }
  }
}
