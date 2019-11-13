//示例 https://github.com/shamblett/mqtt_client/blob/master/example/iot_core.dart
import 'dart:async';
import 'dart:async' show Future;
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:path_provider/path_provider.dart';

import 'mqtt_topic.dart';
import 'mqtt_cert.dart';

///是否测试
bool debug = true;

///测试服
String _serverTest = 'xxx';

///线上
String _serverOnline = 'xxx';

///服务器地址
String _server = debug ? _serverTest : _serverOnline;

///端口号
int _port = 8883;

///超时时间 s
int _keepAlive = 60;

///是否连接上
bool _connected = false;

///是否初始化完成
bool _inited = false;

///每次+5  5，10，15，
int _recontectTimeAdd = 5;

///重连间隔 初始5s 每次重连递增 5s
int _recontectDelay = 5;

MqttClient _client = MqttClient.withPort(_server, "", _port);

class MqttUtils {
  static MqttUtils _instance;

  ///客户端标识符 
  String _clientIdentifier = '';

  Map<String, IMqttCallBack> _topicCallBackMap = new Map();

  static MqttUtils getInstance() {
    if (_instance == null) {
      _instance = MqttUtils();
    }
    return _instance;
  }

  ///测试方法
  void test() async {
    int res = await connect("123456789012345", "123456789012345");
    if (res != 0) {
      print("mqtt connect fail");
      return;
    }
    subscribe(MQTTTopic.response_token, callBack: new MqttCallBack());
    String jsonString = "{\"device_id\":\"${MQTTTopic.device_id}\",\"name\":\"test_name\"}";
    publishMessage(MQTTTopic.response_token, jsonString,
        qualityOfService: MqttQos.atMostOnce);
  }

  ///初始化配置mqtt
  Future<int> init({bool deleteExist: false}) async {
    ///日志
    _client.logging(on: debug);
    //超时时间s  默认为60s
    _client.keepAlivePeriod = _keepAlive;

    /// 安全认证
    _client.secure = true;
    final SecurityContext context = SecurityContext.defaultContext;
   
    try {
      context.setTrustedCertificatesBytes(utf8.encode(cert_ca));
      context.useCertificateChainBytes(utf8.encode(cert_client_crt));
      context.usePrivateKeyBytes(utf8.encode(cert_client_key));
    } on Exception catch (e) {
      //出现异常 证书配置错误
      print("SecurityContext set  error : " + e.toString());
      return -1;
    }
    _client.securityContext = context;
    _client.setProtocolV311();

    ///连接成功回调
    _client.onConnected = onConnected;

    ///连接断开回调
    _client.onDisconnected = onDisconnected;

    ///订阅成功回调
    _client.onSubscribed = onSubscribed;

    _client.pongCallback  = ping;

    _inited = true;
    return 0;
  }

  /// 用户登录之后初始化  0 初始化成功  否则失败
  Future<int> connect(String IMEI, String deviceUid) async {
    MQTTTopic.device_id = IMEI;
    MQTTTopic.device_uid = deviceUid;
    _clientIdentifier = 'xxx-$IMEI';
    _client.clientIdentifier = _clientIdentifier;

    try {
      await _client.connect();
    } on Exception catch (e) {
      print('MqttUtils::client exception - $e');
      _client.disconnect();
    }

    // 检查连接的状态
    if (_client.connectionStatus.state == MqttConnectionState.connected) {
      print('MqttUtils::$_server client connected');
      _connected = true;
    } else {
      print('MqttUtils::ERROR $_server client connection failed - disconnecting, status is ${_client.connectionStatus}');
      _client.disconnect();
      return -1;
    }

    // 监听订阅消息的响应
    _client.updates.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      print('MqttUtils::updates.listen');
      final MqttPublishMessage recMess = c[0].payload;
      String topic = c[0].topic;
      final String dataJson =
      MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      print('MqttUtils::Change notification:: topic is <$topic>, payload is <-- $dataJson -->');

      IMqttCallBack callBack = _topicCallBackMap[topic];
      print("_topicCallBackMap on update  key = $topic, callBack = $callBack}");
      if (callBack != null) {
        callBack.onResponse(topic, dataJson);
      }
    });

    _client.published.listen((MqttPublishMessage message) {
      print('MqttUtils::Published notification:: topic is ${message.variableHeader.topicName}, with Qos ${message.header.qos}');
    });
    return 0;
  }

  /// 发送消息  qualityOfService：对应接口文档的 qos 参数
  bool publishMessage(String topic, String jsonString,
      {bool retain = false, MqttQos qualityOfService = MqttQos.atMostOnce}) {
    print('MqttUtils::publishMessage topic = $topic, MqttQos = $qualityOfService, '
        'jsonString = $jsonString');
    
    if (!isConnected()) {
      print('MqttUtils::publishMessage topic = $topic---- client is not conntected');
      return false;
    }
    
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(jsonString);
    _client.publishMessage(topic, qualityOfService, builder.payload,
        retain: retain);
    return true;
  }

  /// 订阅消息
  bool subscribe(String topic,
      {MqttQos qosLevel = MqttQos.atMostOnce, IMqttCallBack callBack}) {
    print('MqttUtils::subscribe topic = $topic , qosLevel = $qosLevel,'
        'callBack = $callBack');
    
    if (!isConnected()) {
      print('MqttUtils::subscribe  topic = $topic ---- client is not conntected');
      return false;
    }
    
    if (callBack != null) {
      _topicCallBackMap.addAll({topic: callBack});
      print("_topicCallBackMap subscribe put  key = $topic, callBack = ${callBack == null ? null : callBack.toString()}");
    }
    _client.subscribe(topic, qosLevel);
    return true;
  }

  ///取消订阅
  bool unsubscribe(String topic) {
    print('MqttUtils::Unsubscribing' + topic);
    if (!isConnected()) {
      print('MqttUtils::Unsubscribing  topic = $topic---- client is not conntected');
      return false;
    }
    _client.unsubscribe(topic);
    if (_topicCallBackMap.containsKey(topic)) {
      _topicCallBackMap.remove(topic);
    }
    return true;
  }

  ///中断连接
  void disconnect() {
    print('MqttUtils::Disconnecting');
    _client.disconnect();
    _client.securityContext = null;
    _topicCallBackMap.clear();
  }
}

///连接成功的回调
void onConnected() {
  print('MqttUtils::OnConnected client callback - Client connection was sucessful');
}

///订阅成功回调
void onSubscribed(String topic) {
  print('MqttUtils::Subscription confirmed for topic $topic');
}

//断开连接的回调
void onDisconnected() {
  print('MqttUtils::OnDisconnected client callback - Client disconnection');
  _connected = false;
  if (_client.connectionStatus.returnCode == MqttConnectReturnCode.solicited) {
    print('MqttUtils::OnDisconnected callback is solicited, this is correct');
  }
  
  if (_canReConnected()) {
    await Future.delayed(Duration(seconds: _recontectDelay));
    _recontectDelay += _recontectTimeAdd;
    print("mqtt start reConntect");
    MqttUtils.getInstance().connect(MQTTTopic.device_id, MQTTTopic.device_uid);
  }
  //退出程序
  //exit(-1);
}

bool _canReConnected() {
  return _inited &&
      MQTTTopic.device_id != null &&
      MQTTTopic.device_id.length > 0;
}

void ping() {
  print('MqttUtils::Ping response client callback invoked');
}

abstract class IMqttCallBack {
  void onResponse(String topic, String data);
}

class MqttCallBack implements IMqttCallBack {
  @override
  void onResponse(String topic, String data) {
    print("TestCallback topic = $topic ,data = $data");
  }
}

