# Aplicativo de Controle Linear - 

## Sobre o Projeto
Ele permite que os alunos configurem, executem e visualizem os resultados de cinco experimentos de controle distintos diretamente de seus dispositivos móveis, observando em tempo real o comportamento de um motor DC controlado.

## Principais Funcionalidades
Controle Remoto: Envio de parâmetros (ganhos, referências, etc.) para 5 experimentos diferentes.

Monitoramento em Tempo Real: Visualização de dados da planta (velocidade, posição, erro) publicados pelo ESP32.

Arquitetura Modular: Telas dedicadas e auto-suficientes para cada experimento, facilitando a manutenção e a escalabilidade.

Suporte Teórico Integrado: Cada tela de experimento possui um visualizador de PDF embutido para acesso rápido ao guia de laboratório correspondente.

Comunicação via MQTT: Utilização do protocolo MQTT para uma comunicação leve e eficiente entre o app e a bancada.

## Arquitetura e Fluxo de Funcionamento
### Arquitetura Geral
O sistema é composto por três partes principais que se comunicam em tempo real:

Bancada Física (ESP32): O "cérebro" da operação. Recebe os comandos, executa os algoritmos de controle (P, PID, etc.), lê os sensores (encoder) e publica os resultados.

Broker MQTT: O intermediário da comunicação. Ele gerencia as filas de mensagens, garantindo que os comandos do app cheguem ao ESP32 e os dados do ESP32 cheguem ao app.

Aplicativo Flutter (IHM): A interface do usuário. Permite a configuração, o acionamento e a visualização de cada experimento.

O fluxo de dados é bidirecional:

App Flutter <--> Broker MQTT <--> ESP32

### Fluxo do Aplicativo
O aplicativo guia o usuário através de uma sequência lógica de telas, cada uma com um propósito específico.

## 1. Tela de Abertura (Splash Screen)
Arquivo: main.dart

Função: Uma introdução visual que apresenta o aplicativo e as afiliações institucionais (UFU/FEMEC). Após 5 segundos, redireciona para a tela de conexão.

## 2. Tela de Dados e Conexão (UnifiedScreen)
Arquivo: dadosintegrante.dart

Função: O ponto central para a configuração da comunicação.

O usuário insere os dados do broker MQTT (IP, porta, credenciais).

Ao clicar em "Conectar", a classe singleton BrokerInfo estabelece e gerencia a conexão.

Com a conexão ativa, o botão "Avançar para Experimentos" é habilitado.

## 3. Tela de Seleção de Experimentos (EscolhaExperimento)
Arquivo: broker.dart

Função: Atua como o menu principal do aplicativo.

Apresenta 5 botões, cada um representando um laboratório.

Utiliza uma lógica de navegação condicional que direciona o usuário para a tela dedicada correta com base no botão pressionado.

## 4. Telas de Experimento Dedicadas (5 telas)
Arquivos: malha_aberta_fechada_page.dart, sistemas_ordem_page.dart, etc.

Função: O coração do aplicativo, onde a interação com a bancada acontece.

Painel de Controle: Oferece campos de texto para inserir os parâmetros específicos do experimento (ex: Ganhos Kp/Ki/Kd, Referências de velocidade/posição).

Painel de Monitoramento: Exibe em tempo real os dados que o ESP32 está publicando nos tópicos MQTT. A tela se inscreve (subscribes) nesses tópicos e usa ValueListenableBuilder para atualizar os valores na tela automaticamente.

Autonomia: Cada tela gerencia seu próprio estado, suas próprias inscrições MQTT e seus próprios dados, garantindo que o aplicativo seja organizado e fácil de expandir.
