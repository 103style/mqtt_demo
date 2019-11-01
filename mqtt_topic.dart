class MQTTTopic {
  static String device_id = "";
  static String device_uid = "";
  static String response_token = 'account/token_response/$device_id';
  static String request_im_bind_confirm = 'im/$device_uid/confirm';
}
