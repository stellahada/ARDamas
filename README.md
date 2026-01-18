# 🏁 ARDamas - Jogo de Damas iOS

![Swift](https://img.shields.io/badge/swift-F54A2A?style=for-the-badge&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-007AFF?style=for-the-badge&logo=swift&logoColor=white)
![ARKit](https://img.shields.io/badge/ARKit-000000?style=for-the-badge&logo=apple&logoColor=white)
![RealityKit](https://img.shields.io/badge/RealityKit-8E8E93?style=for-the-badge&logo=apple&logoColor=white)

> Uma experiência clássica de Damas reinventada para o mundo real através da Realidade Aumentada.

Este aplicativo iOS permite que jogadores projetem um tabuleiro de damas em qualquer superfície plana e joguem contra amigos próximos sem a necessidade de internet, utilizando conexão ponto a ponto.

---

## 🚀 Funcionalidades

- **Realidade Aumentada (AR):** Detecção de superfícies planas para posicionar o tabuleiro virtual no mundo real.
- **Multiplayer Local (P2P):** Conexão direta entre dispositivos próximos para partidas em tempo real (sem necessidade de Wi-Fi/Servidor).
- **Interatividade 3D:** Peças e tabuleiro renderizados com física e iluminação realistas.
- **Interface Nativa:** Menus e controles construídos inteiramente com SwiftUI.

---

## 🛠️ Tecnologias Utilizadas

O projeto explora o poder do ecossistema Apple para criar uma experiência imersiva.

- **Interface:** SwiftUI
- **Realidade Aumentada:** ARKit (Rastreamento de ambiente)
- **Renderização 3D:** RealityKit (Modelos, física e materiais)
- **Conectividade:** Multipeer Connectivity (Comunicação entre dispositivos)

---

## 📂 Estrutura do Projeto

```bash
/ARDamas
  ├── App/              # Configuração inicial e ciclo de vida
  ├── Models/           # Regras de negócio, Lógica das Peças e Tabuleiro
  ├── ViewModels/       # Gerenciamento de estado (GameVM, ARSessionVM)
  ├── Views/            # Telas e componentes visuais (SwiftUI)
  ├── Services/         # Multipeer Connectivity e Gerenciadores de AR
  └── Resources/        # Assets.xcassets (Modelos 3D .usdz, ícones)
```

---

## ⚙️ Pré-requisitos e Instalação
Para executar este projeto, você precisará de um ambiente macOS configurado.

Requisitos:

Xcode 14+

iPhone ou iPad com processador A9 ou superior (compatível com ARKit)

Cabo Lightning/USB-C para deploy no dispositivo físico

Clone o repositório

```Bash
git clone [https://github.com/SEU_USUARIO/NOME_DO_REPO_DAMAS.git](https://github.com/SEU_USUARIO/NOME_DO_REPO_DAMAS.git)
cd NOME_DO_REPO_DAMAS
```

Abra o projeto Dê um clique duplo no arquivo .xcodeproj ou .xcworkspace.

Configure a Assinatura (Signing) No Xcode, vá na aba Signing & Capabilities e selecione o seu Team de desenvolvimento para permitir a instalação no dispositivo.

---

## ⚡ Como Executar
⚠️ Nota Importante: Funcionalidades de AR e Multipeer Connectivity geralmente não funcionam corretamente no Simulador. Teste em dispositivos físicos reais.

Conecte seu iPhone/iPad ao Mac.

Selecione o dispositivo como "Destination" no topo do Xcode.

Pressione Cmd + R para compilar e rodar.

---

| [<img src="https://avatars.githubusercontent.com/u/151103690?v=4" width=115><br><sub>Henrique Leal</sub>](https://github.com/HenriLeal) | [<img src="https://avatars.githubusercontent.com/u/91349698?v=4" width=115><br><sub>Stella Hada</sub>](https://github.com/stellahada) | 
| :---: | :---: | 
