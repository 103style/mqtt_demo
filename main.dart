import 'package:flutter/material.dart';
import 'mqtt_client.dart';

void main() async {
  print("mian() start");
  //初始化mqtt
  int res = await MqttUtils.getInstance().init();
  print("mqtt init res = $res");
  if (res == 0) {
   await MqttUtils.getInstance().test();
    //runApp(MyApp());
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
    ...
    );
  }
}
