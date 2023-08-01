import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BleDeviceListScreen(),
    );
  }
}

class BluetoothDeviceWithConnection {
  BluetoothDevice device;
  bool isConnected;

  BluetoothDeviceWithConnection(this.device, this.isConnected);
}

class BleDeviceListScreen extends StatefulWidget {
  @override
  _BleDeviceListScreenState createState() => _BleDeviceListScreenState();
}

class _BleDeviceListScreenState extends State<BleDeviceListScreen> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  List<BluetoothDevice> devicesList = [];
  List<BluetoothDeviceWithConnection> connectedDevices = [];
  bool isScanning = false;
  BluetoothCharacteristic? broadcastCharacteristic;
  String _broadcastData = '브로드캐스팅 데이터 없음';

  @override
  void initState() {
    super.initState();
    _checkBluetoothPermission();
  }

  void _checkBluetoothPermission() async {
    var status = await Permission.bluetooth.status;
    if (status.isGranted) {
      _startScan();
    } else {
      if (await Permission.bluetooth.request().isGranted) {
        _startScan();
      } else {
        // 블루투스 권한 거부 시 대응 로직 추가
      }
    }
  }

  void _startScan() {
    if (isScanning) return;
    setState(() {
      isScanning = true;
    });

    _getConnectedDevices(); // 이미 연결되어 있는 기기들 가져오기

    flutterBlue.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.name == "Electronic Scale") {
          bool alreadyConnected =
              connectedDevices.any((device) => device.device.id == r.device.id);
          if (!alreadyConnected) {
            setState(() {
              devicesList.add(r.device);
            });
            _connectToDevice(r.device);
          }
        }
      }
    });

    flutterBlue.startScan(timeout: Duration(seconds: 4)).then((value) {
      setState(() {
        isScanning = false;
      });
    }).catchError((error) {
      setState(() {
        isScanning = false;
      });
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      print('${device.name} (${device.id})에 연결되었습니다.');
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        service.characteristics.forEach((characteristic) {
          if (characteristic.properties.notify) {
            characteristic.setNotifyValue(true);
            characteristic.value.listen((value) {
              setState(() {
                broadcastCharacteristic = characteristic;
                _broadcastData = value.toString();
              });
            });
          }
        });
      }
      setState(() {
        connectedDevices.add(BluetoothDeviceWithConnection(device, true));
      });
    } catch (e) {
      print('${device.name} (${device.id})에 연결 중 오류가 발생하였습니다: $e');
    }
  }

  Future<void> _getConnectedDevices() async {
    List<BluetoothDevice> connectedDevicesList =
        await flutterBlue.connectedDevices;
    setState(() {
      connectedDevices = connectedDevicesList
          .where((device) => device.name == "Electronic Scale")
          .map((device) => BluetoothDeviceWithConnection(device, true))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BLE 디바이스 목록'),
      ),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                _startScan();
              },
              child: Text('디바이스 검색'),
            ),
            if (connectedDevices.isNotEmpty) ...[
              for (var device in connectedDevices)
                Column(
                  children: [
                    ListTile(
                      title: Text('이름: ${device.device.name}'),
                      subtitle: Text('디바이스 ID: ${device.device.id}'),
                    ),
                    if (broadcastCharacteristic != null) ...[
                      StreamBuilder<List<int>>(
                        stream: broadcastCharacteristic!.value,
                        initialData: [],
                        builder: (context, snapshot) {
                          List<int> broadcastData = snapshot.data!;
                          String broadcastInfo = broadcastData.isEmpty
                              ? '브로드캐스팅 데이터 없음'
                              : '브로드캐스팅 데이터: ${broadcastData.join(', ')}';
                          return ListTile(
                            title: Text(broadcastInfo),
                          );
                        },
                      ),
                    ],
                  ],
                ),
            ],
            if (devicesList.isNotEmpty) ...[
              for (var device in devicesList)
                ListTile(
                  title: Text('이름: ${device.name}'),
                  subtitle: Text('디바이스 ID: ${device.id}'),
                  onTap: () {
                    _connectToDevice(device);
                  },
                ),
              ListTile(
                title: Text(_broadcastData),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
