# Como Resolver o Erro "Unsupported class file major version 65"

## Problema
O erro ocorre porque o Gradle 8.0 requer Java 11+, mas você está usando Java 8.

## Solução Passo a Passo

### Passo 1: Fechar o Android Studio
1. Feche completamente o Android Studio
2. Verifique no Gerenciador de Tarefas se há processos `java.exe` ou `gradle.exe` rodando
3. Se houver, encerre todos os processos

### Passo 2: Limpar Cache do Gradle
No PowerShell (como Administrador):

```powershell
# Parar todos os processos Gradle
Get-Process | Where-Object {$_.ProcessName -like "*gradle*"} | Stop-Process -Force

# Parar todos os processos Java
Get-Process | Where-Object {$_.ProcessName -like "*java*"} | Stop-Process -Force

# Remover cache do Gradle
Remove-Item -Path "C:\Users\Charles\.gradle\caches" -Recurse -Force -ErrorAction SilentlyContinue
```

### Passo 3: Abrir o Android Studio Novamente
1. Abra o Android Studio
2. File → Open → `C:\Users\Charles\Documents\ProjetoERP_1\Android\android`

### Passo 4: Configurar Gradle no Android Studio
1. File → Settings → Build, Execution, Deployment → Build Tools → Gradle
2. **Gradle JDK:** Selecione "jre1.8.0_501" (ou 1.8)
3. Clique em Apply → OK

### Passo 5: Sincronizar o Projeto
1. File → Sync Project with Gradle Files
2. Aguarde o sync completar

### Passo 6: Executar o Build
1. Build → Clean Project
2. Build → Rebuild Project

## Configurações Atuais do Projeto

As seguintes configurações já foram aplicadas:

**build.gradle (raiz):**
- Android Gradle Plugin: 7.4.2 (compatível com Java 8)

**gradle-wrapper.properties:**
- Gradle: 7.5 (compatível com Java 8)

**app/build.gradle:**
- sourceCompatibility: Java 1.8
- targetCompatibility: Java 1.8

## Alternativa: Instalar Java 11

Se preferir usar versões mais recentes do Gradle/Android Gradle Plugin:

1. Baixe e instale Java 11: https://adoptium.net/temurin/releases/?version=11
2. Configure no Android Studio: File → Settings → Build, Execution, Deployment → Build Tools → Gradle
3. Gradle JDK: Selecione o Java 11 instalado
4. Reverter as alterações nos arquivos para usar Gradle 8.0 e Android Gradle Plugin 8.0.2

## Se o Problema Persistir

Tente usar a linha de comando diretamente:

```powershell
cd C:\Users\Charles\Documents\ProjetoERP_1\Android\android
.\gradlew clean build --refresh-dependencies
```

Se ainda assim não funcionar, a solução definitiva é instalar Java 11 ou superior.
