import 'package:flutter/material.dart';

import '../models.dart';

class DeviceInfoScreen extends StatelessWidget {
  final YubiKeyData device;
  const DeviceInfoScreen(this.device, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('This page intentionally left blank (for now)'),
        ],
      ),
    );
  }
}