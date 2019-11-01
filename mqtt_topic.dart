class MQTTTopic {
  static String device_id = "";
  static String device_uid = "";
  static String request_token = 'account/token_request/$device_id';
  static String request_im_bind_confirm = 'im/$device_uid/confirm';
}
