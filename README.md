# 📦 Export CloudWatch Logs to S3 Glacier

Este projeto contém um **script em Bash** que automatiza a **exportação de logs do AWS CloudWatch para o Amazon S3**, aplicando posteriormente uma **política de ciclo de vida** para mover os arquivos para o **S3 Glacier**.  

O objetivo é garantir que os logs sejam armazenados de forma segura, com baixo custo e atendendo requisitos de retenção de longo prazo.

---

## 🚀 Funcionalidades

- 🔎 **Listagem dos Log Groups** no CloudWatch.
- 🏷️ **Filtragem por Tag (`BACKUP_LOGS_GLACIER=true`)** para decidir quais Log Groups exportar.
- 📥 **Criação do bucket S3** (se não existir) com:
  - Política de permissões para exportação do CloudWatch.
  - Diretório por **ano** para organização dos logs.
- ⏳ **Exportação dos logs** de um período específico (últimos 7 dias).
- 📤 **Envio dos logs exportados para o S3**.
- ❄️ **Configuração de ciclo de vida no bucket**:
  - Transição para **Glacier** após **1 dia**.
  - Expiração automática após **1874 dias (~5 anos)**.
- 📧 **Notificação por e-mail**:
  - Sucesso: `Success to Export Logs to S3 Glacier`
  - Falha: `Failed to Export Logs to S3 Glacier`

---

## ⚙️ Estrutura

- **Variáveis principais:**
  - `AWS_REGION="sa-east-1"`
  - `CLIENT_NAME=$(facter client)` → usado para personalizar bucket, e-mails e nomes.
  - `S3_BUCKET_NAME="$CLIENT_NAME-prd-app-logs-glacier"`
  - `GLACIER_STORAGE_CLASS="GLACIER"`
  - `GLACIER_VAULT_NAME="backup-logs-app"`
  - `TRANSITION_DAYS=1` → Transição para Glacier.
  - `EXPIRATION_DAYS=1874` → Expiração dos logs.

- **Funções implementadas:**
  - `send_email()` → Envia notificação de sucesso ou falha.
  - `listLogGroupsName()` → Lista os Log Groups existentes.
  - `verifyTagLogGroup()` → Verifica se o Log Group possui a tag `BACKUP_LOGS_GLACIER=true`.
  - `getAccoutID()` → Obtém o ID da conta AWS.
  - `createBucketS3()` → Cria bucket e aplica política.
  - `createDirectoryYear()` → Cria pasta do ano no bucket, se necessário.
  - `exportLogsToS3()` → Exporta logs de cada Log Group elegível.
  - `configureLifeCycleS3BucketClass()` → Configura ciclo de vida do bucket para Glacier.

---

## 🛠️ Pré-requisitos

- **AWS CLI** configurado com credenciais válidas  
  ```bash
  aws configure --profile <perfil>
