class BrokerConfig {
  static final BrokerConfig _instance = BrokerConfig._internal();

  String ip = '';
  int porta = 1883;
  String usuario = '';
  String senha = '';
  String espWifiStatus = '';
  String espBrokerStatus = '';

  factory BrokerConfig() {
    return _instance;
  }

  BrokerConfig._internal();
}
