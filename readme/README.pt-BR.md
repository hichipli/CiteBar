<div align="center">

[English](../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · **Português** · [Deutsch](README.de.md) · [Français](README.fr.md) · [Русский](README.ru.md)

<img src="../Assets.xcassets/AppIcon.appiconset/256.png" alt="Logo do CiteBar" width="112" height="112">

# CiteBar

**Pare de atualizar o Google Scholar.**<br>
Para todo mundo que confere as próprias citações um pouco vezes demais.

[Baixar](https://github.com/hichipli/CiteBar/releases/latest) · [Site](https://www.citebar.org/) · `brew install --cask hichipli/tap/citebar`

  [![Latest Release](https://img.shields.io/github/v/release/hichipli/CiteBar?style=flat-square)](https://github.com/hichipli/CiteBar/releases)
  [![macOS](https://img.shields.io/badge/macOS-13.0+-blue?style=flat-square)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square)](https://swift.org)
  [![License](https://img.shields.io/github/license/hichipli/CiteBar?style=flat-square)](../LICENSE)
  [![Downloads](https://img.shields.io/github/downloads/hichipli/CiteBar/total?style=flat-square)](https://github.com/hichipli/CiteBar/releases)

<img src="../website/assets/demo.gif" alt="Do painel na barra de menus ao estúdio do Citation Record: a máquina do tempo é arrastada de volta ao dia em que o perfil chegou a 1.000 citações e, em seguida, os temas Gazette, Certificate e Night são testados" width="420">

</div>

---

## Por que o CiteBar?

Porque atualizar seu perfil do Google Scholar a cada 20 minutos não faz a pesquisa andar. O CiteBar transforma aquela aba do navegador que você não consegue largar em uma companhia discreta na barra de menus: ele verifica uma vez por dia, avisa qual artigo acabou de ser citado e não atrapalha no resto do tempo.

Ideal para pesquisadores que acompanham o impacto dos seus artigos, doutorandos comemorando as primeiras citações, líderes de laboratório que acompanham o grupo inteiro e qualquer pessoa que já se perguntou: "Será que meu h-index acabou de subir?"

## Primeiros passos

**Só quer usar o CiteBar?** Pule a parte técnica e comece em cerca de um minuto.

1. **Baixe a versão mais recente**
   - Acesse o [GitHub Releases](https://github.com/hichipli/CiteBar/releases/latest).
   - Baixe o arquivo `CiteBar-x.x.x-universal-[date].dmg`.
   - O DMG universal funciona tanto em Macs com Apple Silicon quanto com Intel.
   - Prefere o Homebrew? `brew install --cask hichipli/tap/citebar` faz os passos 1 e 2 por você.

2. **Instale o CiteBar**
   - Abra o DMG.
   - Arraste `CiteBar.app` para a pasta `Applications` (Aplicativos).
   - Abra o CiteBar a partir de `Applications`.

3. **Adicione seu perfil**
   - Na primeira vez que você abrir o app, o CiteBar mostra a janela Add Profiles. Cole o link do seu perfil no Google Scholar.
   - Quer acompanhar um laboratório ou seus coautores? Cole todos os links de uma vez, um por linha, e coloque-os em um grupo.
   - Por padrão, a atualização é diária. O próprio Google Scholar é atualizado a cada um ou dois dias, então isso já basta para manter o CiteBar em dia.

Você pode colar o link completo do perfil ou só o ID, que é o valor de `user` na URL:

```text
https://scholar.google.com/citations?user=YOUR_ID_HERE
```

As versões atuais são assinadas com Apple Developer ID e notarizadas pela Apple. Mesmo assim, o macOS pode exibir a confirmação de costume na primeira vez que você abre um app baixado da internet.

Se você está atualizando a partir da `1.3.x` ou da `1.4.1`, instale manualmente o DMG mais recente uma única vez. Depois disso, as atualizações automáticas dentro do app devem funcionar normalmente.

Problemas na instalação? Veja o [Guia de instalação](../DISTRIBUTION.md) (em inglês).

## Recursos que fazem diferença

<img src="../website/assets/panel.png" alt="O painel do CiteBar: um perfil com 1.284 citações, citações por ano, um artigo citado recentemente, os dois artigos que levariam o h-index a 14, dois artigos acompanhados e um grupo de laboratório com o total de citações" width="360">

**O número, com contexto**
- Sua contagem de citações fica na barra de menus; clique nela para abrir o painel
- Citações por ano, total deste ano, crescimento em 30 dias, h-index e i10-index
- Veja qual artigo acabou de ser citado e clique para ver quem o citou
- Quando o próximo h-index estiver perto, veja exatamente quais artigos precisam de citações e quantas faltam para cada um
- Acompanhe artigos específicos: marque-os com estrela na Papers window para mantê-los no painel, com as citações mais recentes deles aparecendo primeiro nas notificações
- Rótulos nas colunas e dicas ao passar o mouse explicam cada número

**Grupos para laboratórios e colaboradores**
- Agrupe perfis em um laboratório, coautores ou uma turma, com o total de citações e o crescimento em 30 dias
- Cole uma lista inteira de links do Scholar de uma só vez
- Copie os links de um grupo para compartilhar com os colegas de laboratório, que podem colá-los no CiteBar deles

**Notificações que valem a pena abrir**
- As notificações dizem quais artigos ganharam citações
- Marcos como 100 ou 1.000 citações, ou um h-index maior, ganham um aviso próprio
- Nada de avisos do tipo "nada mudou"

**Um registro de citações para compartilhar**
- Quatro estilos de cartão: Record, Night, Gazette (uma primeira página de jornal com manchete escrita a partir dos seus números) e Certificate
- Escolha o que aparece: citações por ano, h-index, artigos mais citados ou um artigo específico, crescimento entre 7 e 365 dias e uma nota
- Compartilhe (AirDrop, Mensagens, Mail), copie ou salve com um clique, a partir do painel ou do menu ⋯ de qualquer perfil nos ajustes

<img src="../website/assets/card-record.png" alt="Cartão Record" width="180"> <img src="../website/assets/card-night.png" alt="Cartão Night" width="180"> <img src="../website/assets/card-gazette.png" alt="Cartão Gazette" width="180"> <img src="../website/assets/card-certificate.png" alt="Cartão Certificate" width="180">

**Uma máquina do tempo para o seu histórico**
- Arraste ao longo de uma linha do tempo até qualquer dia e gere o cartão daquele dia
- Marcos de citações e aumentos do h-index ficam destacados, para você compartilhar um momento que deixou passar
- Funciona desde o primeiro dia: marcos anteriores à instalação do CiteBar são datados a partir das contagens anuais do Google Scholar e marcados com ~, e cada dia desde então é registrado com exatidão

**Respeitoso e confiável**
- Uma requisição por perfil, com dois segundos de intervalo entre elas
- Falhas de rede são repetidas automaticamente; diante dos limites de requisição do Google Scholar, o app espera cada vez mais (de 15 minutos até 4 horas) e retoma sozinho
- Refresh Now funciona a qualquer momento
- Atualizações automáticas via Sparkle

**Privacidade em primeiro lugar**
- Todos os dados ficam no seu Mac
- Sem telemetria
- Sem servidores nem contas do CiteBar

**Seus dados, onde você quiser**
- Settings › Data mostra onde os dados ficam (`~/Library/Application Support/CiteBar/`) e quanto espaço ocupa cada parte: histórico de citações, listas de artigos e histórico de artigos
- Mantenha o histórico de citações para sempre (o padrão) ou por 5, 2 ou 1 ano
- O histórico de artigos, opcional, salva a contagem de cada artigo sempre que ela muda, para que os dias passados na máquina do tempo também mostrem os artigos
- Exporte tudo (perfis, grupos, ajustes e histórico completo) para um único arquivo e importe em um Mac novo; a importação só adiciona, nunca apaga
- Backup automático opcional após cada atualização, no iCloud Drive ou em qualquer pasta que você escolher, como Google Drive ou Dropbox

**Experiência nativa do macOS**
- Presença leve na barra de menus, com modo claro e escuro
- Ajustes nativos com as abas Profiles, General, Data e About
- Opção de abrir ao iniciar a sessão
- Compatível com Apple Silicon e Intel

**Leve o bastante para ficar sempre aberto**
- Uso de CPU praticamente nulo quando ocioso
- Atividade de rede mínima, nos intervalos que você definir
- Mais detalhes de implementação nas [Notas técnicas](../TECHNICAL.md) (em inglês)

## Privacidade

O CiteBar só lê páginas públicas de perfis do Google Scholar. Seus ajustes e seu histórico de citações ficam no seu Mac, em `~/Library/Application Support/CiteBar/`.

O app usa intervalos de atualização conservadores, pausas entre requisições e espera progressiva após erros, para consultar as contagens de citações de forma responsável.

## Ajuda e documentação do projeto

- Instalação ou avisos de segurança do macOS: [Guia de instalação](../DISTRIBUTION.md)
- Compilar a partir do código-fonte: [Guia de configuração](../SETUP.md)
- Bugs e sugestões de recursos: [GitHub Issues](https://github.com/hichipli/CiteBar/issues)
- Mudanças no projeto: [Changelog](../CHANGELOG.md)

Esses documentos estão em inglês, mas você pode abrir issues em português.

Tem uma ideia, uma sugestão de recurso ainda crua ou um fluxo de trabalho que o CiteBar ainda não atende bem? Abra uma issue. Não precisa chegar com uma proposta polida nem com um pull request; feedback prático vindo do dia a dia real da pesquisa já é valioso por si só.

## Desenvolvedores e colaboradores

Quer compilar a partir do código-fonte, contribuir com código ou entender como o CiteBar funciona por dentro?

```bash
git clone https://github.com/hichipli/CiteBar.git
cd CiteBar
make build
make run
```

Documentação útil do projeto (em inglês):

- [Guia de contribuição](../CONTRIBUTING.md)
- [Notas técnicas](../TECHNICAL.md)
- [Guia de releases](../RELEASING.md)
- [Gerenciamento de versões](../VERSION_MANAGEMENT.md)

## Licença

O CiteBar é distribuído sob a [Licença MIT](../LICENSE).

## Comunidade

Obrigado a todas as pessoas que ajudam a tornar o CiteBar melhor.

<div>
  <a href="https://github.com/CassWang1"><img src="https://github.com/CassWang1.png?size=48" width="48" alt="CassWang1" /></a>
  <a href="https://github.com/lukestein"><img src="https://github.com/lukestein.png?size=48" width="48" alt="lukestein" /></a>
  <a href="https://github.com/DABH"><img src="https://github.com/DABH.png?size=48" width="48" alt="DABH" /></a>
  <a href="https://github.com/yizirui"><img src="https://github.com/yizirui.png?size=48" width="48" alt="yizirui" /></a>
</div>

---

<div align="center">

**Feito com carinho para a comunidade acadêmica**

[Baixar a versão mais recente](https://github.com/hichipli/CiteBar/releases/latest) | [Relatar um problema](https://github.com/hichipli/CiteBar/issues) | [Contribuir](../CONTRIBUTING.md)

</div>
