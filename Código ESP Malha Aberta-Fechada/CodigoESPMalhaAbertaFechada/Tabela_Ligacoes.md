# Tabela de Ligações
A tabela abaixo descreve as conexões físicas entre o ESP32, o driver L298N (utilizando o Canal B) e o encoder, conforme configurado no firmware final.

## Do Componente Driver L298N	
Pino do Componente	Para o ESP32	Pino do ESP32
IN3	                     →	      GPIO 26
IN4	                     →	      GPIO 27
ENB	                     →	      GPIO 25
5V (Lógica)	             →	      3V3
GND	                     →	      GND

## Do Componente Encoder
Pino do Componente	Para o ESP32	Pino do ESP32
EncA	              →	            GPIO 34
EncB	              →	            GPIO 35
Vcc	                →	            VIN (5V)
GND	                →	            GND


# Notas Importantes sobre a Alimentação:

## Alimentação do Motor: O terminal +12V (ou VMS) do L298N deve ser conectado ao terminal positivo (+) da sua fonte DC externa. O GND do L298N vai no negativo (-).

## Terra Comum (Obrigatório): É crucial conectar um fio do pino GND do L298N a um pino GND do ESP32. Sem isso, o sistema não funcionará.
