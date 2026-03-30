# Correção: "No Directionality widget found"

## Diagnóstico

### O erro

```
No Directionality widget found.
Scaffold widgets require a Directionality widget ancestor.
The specific widget that could not find a Directionality ancestor was:
  Scaffold
The ownership chain for the affected widget is: "Scaffold ←
  _DefaultErrorFallback ← ErrorBoundary ← _FocusInheritedScope ←
  _FocusScopeWithExternalFocusNode ← _FocusInheritedScope ← Focus ←
  FocusTraversalGroup ← MediaQuery ← _MediaQueryFromView ← …"
```

### Causa raiz

O problema está no arquivo **`frontend/lib/core/widgets/error_boundary.dart`**.

No `main.dart`, a hierarquia de widgets é:

```dart
runApp(
  ErrorBoundary(          // ← ACIMA do MaterialApp
    child: ProviderScope(
      child: NexusHubApp(),  // ← MaterialApp.router está aqui dentro
    ),
  ),
);
```

O `ErrorBoundary` fica **acima** do `MaterialApp` na árvore de widgets. Quando qualquer erro ocorre dentro do app (por exemplo, ao carregar dados da comunidade), o `ErrorBoundary` captura o erro e substitui toda a árvore filha pelo widget `_DefaultErrorFallback`.

O problema é que o `_DefaultErrorFallback` original usava diretamente um `Scaffold`, que **precisa** de um `MaterialApp` (ou pelo menos um `Directionality` widget) como ancestral para funcionar. Como o `MaterialApp` foi removido da árvore (ele era filho do `ErrorBoundary` e foi substituído pelo fallback), o `Scaffold` não encontra o `Directionality` widget e lança o erro vermelho que você viu.

### Por que acontece ao entrar em uma comunidade?

Qualquer erro não tratado dentro da `CommunityDetailScreen` (falha de rede, dados nulos, etc.) é capturado pelo `ErrorBoundary` global. Quando o fallback tenta renderizar, ele falha por falta de `Directionality`, criando o erro em cascata.

## Correção aplicada

**Arquivo:** `frontend/lib/core/widgets/error_boundary.dart`

**Mudança:** Envolver o `_DefaultErrorFallback` em um `MaterialApp` próprio, garantindo que `Directionality`, `MediaQuery`, `DefaultTextStyle`, `Theme` e todos os outros `InheritedWidget` necessários estejam disponíveis.

### Antes (com bug)

```dart
class _DefaultErrorFallback extends StatelessWidget {
  // ...
  @override
  Widget build(BuildContext context) {
    return Scaffold(  // ← Scaffold SEM MaterialApp ancestral = ERRO
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        // ...
      ),
    );
  }
}
```

### Depois (corrigido)

```dart
class _DefaultErrorFallback extends StatelessWidget {
  // ...
  @override
  Widget build(BuildContext context) {
    return MaterialApp(  // ← MaterialApp fornece Directionality + tudo mais
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: SafeArea(
          // ... (mesmo conteúdo de antes)
        ),
      ),
    );
  }
}
```

## Como aplicar

Substitua o conteúdo do arquivo `frontend/lib/core/widgets/error_boundary.dart` pelo arquivo corrigido que está neste repositório, ou aplique manualmente a mudança descrita acima.

## Alternativa: mover o ErrorBoundary para dentro do MaterialApp

Outra abordagem seria mover o `ErrorBoundary` para **dentro** do `MaterialApp`, em vez de envolvê-lo. Isso faria com que o fallback herdasse automaticamente o `Directionality` do `MaterialApp`:

```dart
// main.dart — abordagem alternativa
runApp(
  ProviderScope(
    child: NexusHubApp(), // MaterialApp com ErrorBoundary DENTRO
  ),
);

// Dentro de NexusHubApp:
MaterialApp.router(
  // ...
  builder: (context, child) {
    return ErrorBoundary(
      child: child ?? const SizedBox.shrink(),
    );
  },
);
```

Ambas as abordagens resolvem o problema. A correção aplicada (envolver o fallback em `MaterialApp`) é a mais simples e não exige reestruturar o `main.dart`.
