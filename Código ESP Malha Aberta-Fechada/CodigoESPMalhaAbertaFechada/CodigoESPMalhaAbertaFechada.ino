// Includes de bibliotecas
#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ESP32Encoder.h>

// ==========================================================
// == 1. CONFIGURAÇÕES
// ==========================================================
const char* SSID = "Galaxy";
const char* PASSWORD = "5an5un65al";
const char* MQTT_BROKER = "192.168.118.146";
const int MQTT_PORT = 1883;

// ==========================================================
// == 2. MAPEAMENTO DE PINOS (MOTOR DC COM L298N)
// ==========================================================
// Pinos da Ponte H L298N
const int MOTOR_PWM_PIN = 25; // Deve estar ligado ao pino ENB do L298N
const int MOTOR_IN3_PIN = 26; // Deve estar ligado ao pino IN3 do L298N
const int MOTOR_IN4_PIN = 27; // Deve estar ligado ao pino IN4 do L298N

// Pinos do Encoder do motor
const int ENCODER_A_PIN = 34;
const int ENCODER_B_PIN = 35;

// ==========================================================
// == 3. CONFIGURAÇÕES DO MOTOR
// ==========================================================
const float ENCODER_PPR = 334.0 * 4.0;

// ==========================================================
// == 4. OBJETOS E VARIÁVEIS DE ESTADO
// ==========================================================
ESP32Encoder encoder;

enum ControlMode { PARADO, MALHA_ABERTA, MALHA_FECHADA };
ControlMode currentMode = PARADO;

float param_u_MA = 0.0;
float param_ref_MF = 0.0;
float param_Kp_MF = 0.1;

float u_control = 0.0;
float erro_MF = 0.0;
float vel_rpm = 0.0;

long encoder_pos = 0;
long encoder_pos_ant = 0;

unsigned long time_curr = 0, time_prev = 0;
double dt_sec = 0.0;

unsigned long lastControlTime = 0;
unsigned long lastMqttPublishTime = 0;

// ==========================================================
// == 5. OBJETOS DE WIFI E MQTT
// ==========================================================
WiFiClient espClient;
PubSubClient client(espClient);

// ==========================================================
// == 6. PROTÓTIPOS DE FUNÇÕES
// ==========================================================
void setup_wifi();
void callback(char* topic, byte* payload, unsigned int length);
void reconnect();
void publishMqttData();

// ==========================================================
// == 7. FUNÇÃO SETUP
// ==========================================================
void setup() {
  Serial.begin(115200);
  Serial.println("\n>>> Iniciando ESP32 - Controle de Motor via MQTT <<<");

  // --- Configuração dos Pinos do Motor - 
  pinMode(MOTOR_IN3_PIN, OUTPUT);
  pinMode(MOTOR_IN4_PIN, OUTPUT);
  pinMode(MOTOR_PWM_PIN, OUTPUT);

  // Define um sentido de giro padrão usando IN3 e IN4
  digitalWrite(MOTOR_IN3_PIN, HIGH);
  digitalWrite(MOTOR_IN4_PIN, LOW);
  
  analogWrite(MOTOR_PWM_PIN, 0); // Controla a velocidade via ENB
  Serial.println("-> Pinos do Motor configurados.");

  // --- Configuração do Encoder com a nova biblioteca
  encoder.attachHalfQuad(ENCODER_A_PIN, ENCODER_B_PIN);
  encoder.setCount(0);
  Serial.println("-> Encoder configurado usando o periférico PCNT do ESP32.");
  
  setup_wifi();
  client.setServer(MQTT_BROKER, MQTT_PORT);
  client.setCallback(callback);
  
  time_prev = micros();
}

// ==========================================================
// == 8. FUNÇÃO LOOP PRINCIPAL 
// ==========================================================
void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  unsigned long now = millis();

  if (now - lastControlTime >= 20) {
    lastControlTime = now;

    encoder_pos_ant = encoder_pos;
    encoder_pos = encoder.getCount(); // AQUI: Use getCount()

    double pos_deg = (encoder_pos * 360.0) / ENCODER_PPR;
    double pos_deg_ant = (encoder_pos_ant * 360.0) / ENCODER_PPR;

    time_curr = micros();
    dt_sec = (time_curr - time_prev) / 1000000.0;
    time_prev = time_curr;
    
    if (dt_sec > 0) {
      vel_rpm = ((pos_deg - pos_deg_ant) / dt_sec) / 6.0;
    }

    switch (currentMode) {
      case MALHA_ABERTA:
        u_control = param_u_MA;
        erro_MF = 0;
        break;
      case MALHA_FECHADA:
        erro_MF = param_ref_MF - vel_rpm;
        u_control = param_Kp_MF * erro_MF;
        break;
      case PARADO:
      default:
        u_control = 0;
        erro_MF = 0;
        break;
    }

    u_control = constrain(u_control, 0.0, 90.0);
    analogWrite(MOTOR_PWM_PIN, map(u_control, 0, 100, 0, 255));
  }

  if (now - lastMqttPublishTime >= 500) {
    lastMqttPublishTime = now;
    if (client.connected()) {
      publishMqttData();
    }
  }
}

// ==========================================================
// == 9. FUNÇÕES AUXILIARES 
// ==========================================================
void setup_wifi() {
  delay(10);
  Serial.print("\nConectando a rede Wi-Fi: ");
  Serial.println(SSID);
  WiFi.begin(SSID, PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWi-Fi conectado!");
  Serial.print("Endereço IP: ");
  Serial.println(WiFi.localIP());
}

void callback(char* topic, byte* payload, unsigned int length) {
  String message;
  message.reserve(length);
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  
  String topicStr = String(topic);
  Serial.printf("Mensagem recebida -> Tópico: %s, Valor: %s\n", topicStr.c_str(), message.c_str());

  float value = message.toFloat();

  if (topicStr == "uMA") {
    param_u_MA = value;
    currentMode = MALHA_ABERTA;
    Serial.printf("-> MODO: Malha Aberta. U = %.2f %%\n", param_u_MA);
  } else if (topicStr == "refMF") {
    param_ref_MF = value;
    currentMode = MALHA_FECHADA;
    Serial.printf("-> MODO: Malha Fechada. Referência = %.2f RPM\n", param_ref_MF);
  } else if (topicStr == "KpMF") {
    param_Kp_MF = value;
    Serial.printf("-> Parâmetro atualizado: Kp = %.4f\n", param_Kp_MF);
  } else if (topicStr == "controle/comando") {
    if (message == "PARAR") {
      currentMode = PARADO;
      encoder.setCount(0); // AQUI: Use setCount(0)
      encoder_pos = 0;
      vel_rpm = 0;
      Serial.println("-> COMANDO: Parar motor. Contador do encoder zerado.");
    }
  }
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Tentando conectar ao Broker MQTT...");
    String clientId = "ESP32_Motor_Client_";
    clientId += String(random(0xffff), HEX);
    
    if (client.connect(clientId.c_str())) {
      Serial.println("Conectado!");
      client.subscribe("uMA");
      client.subscribe("refMF");
      client.subscribe("KpMF");
      client.subscribe("controle/comando");
      Serial.println("Subscrição aos tópicos realizada.");
    } else {
      Serial.print("Falha, rc=");
      Serial.print(client.state());
      Serial.println(" | Tentando novamente em 5 segundos");
      delay(5000);
    }
  }
}

void publishMqttData() {
  char msgBuffer[10];

  dtostrf(vel_rpm, 4, 2, msgBuffer);
  client.publish("motor/velocidade", msgBuffer);
  
  if(currentMode == PARADO) client.publish("motor/status", "PARADO");
  else if(currentMode == MALHA_ABERTA) client.publish("motor/status", "MALHA_ABERTA");
  else if(currentMode == MALHA_FECHADA) client.publish("motor/status", "MALHA_FECHADA");

  if (currentMode == MALHA_FECHADA) {
    dtostrf(u_control, 4, 2, msgBuffer);
    client.publish("uMF", msgBuffer);
    dtostrf(erro_MF, 4, 2, msgBuffer);
    client.publish("erroMF", msgBuffer);
  }
}
