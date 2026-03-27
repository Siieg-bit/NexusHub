/// ============================================================================
/// Validators — Validação padronizada de formulários para o NexusHub.
///
/// Todos os métodos retornam null se válido, ou String com mensagem de erro.
/// Uso com TextFormField: validator: Validators.required('Campo obrigatório'),
/// ============================================================================

class Validators {
  Validators._();

  /// Campo obrigatório
  static String? Function(String?) required([String? message]) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return message ?? 'Este campo é obrigatório';
      }
      return null;
    };
  }

  /// Comprimento mínimo
  static String? Function(String?) minLength(int min, [String? message]) {
    return (value) {
      if (value == null || value.trim().length < min) {
        return message ?? 'Mínimo de $min caracteres';
      }
      return null;
    };
  }

  /// Comprimento máximo
  static String? Function(String?) maxLength(int max, [String? message]) {
    return (value) {
      if (value != null && value.trim().length > max) {
        return message ?? 'Máximo de $max caracteres';
      }
      return null;
    };
  }

  /// Email válido
  static String? Function(String?) email([String? message]) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return message ?? 'Email é obrigatório';
      }
      final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (!regex.hasMatch(value.trim())) {
        return message ?? 'Email inválido';
      }
      return null;
    };
  }

  /// Senha forte (mín 8 chars, 1 maiúscula, 1 minúscula, 1 número)
  static String? Function(String?) password([String? message]) {
    return (value) {
      if (value == null || value.isEmpty) {
        return 'Senha é obrigatória';
      }
      if (value.length < 8) {
        return 'Senha deve ter no mínimo 8 caracteres';
      }
      if (!RegExp(r'[A-Z]').hasMatch(value)) {
        return 'Senha deve conter pelo menos uma letra maiúscula';
      }
      if (!RegExp(r'[a-z]').hasMatch(value)) {
        return 'Senha deve conter pelo menos uma letra minúscula';
      }
      if (!RegExp(r'[0-9]').hasMatch(value)) {
        return 'Senha deve conter pelo menos um número';
      }
      return null;
    };
  }

  /// Confirmação de senha
  static String? Function(String?) confirmPassword(String password,
      [String? message]) {
    return (value) {
      if (value != password) {
        return message ?? 'As senhas não coincidem';
      }
      return null;
    };
  }

  /// Nickname (3-20 chars, alfanumérico + underscore)
  static String? Function(String?) nickname([String? message]) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return 'Nickname é obrigatório';
      }
      if (value.trim().length < 3) {
        return 'Nickname deve ter no mínimo 3 caracteres';
      }
      if (value.trim().length > 20) {
        return 'Nickname deve ter no máximo 20 caracteres';
      }
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
        return 'Nickname pode conter apenas letras, números e _';
      }
      return null;
    };
  }

  /// Nome de comunidade (3-50 chars)
  static String? Function(String?) communityName([String? message]) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return 'Nome da comunidade é obrigatório';
      }
      if (value.trim().length < 3) {
        return 'Nome deve ter no mínimo 3 caracteres';
      }
      if (value.trim().length > 50) {
        return 'Nome deve ter no máximo 50 caracteres';
      }
      return null;
    };
  }

  /// URL válida
  static String? Function(String?) url([String? message]) {
    return (value) {
      if (value == null || value.trim().isEmpty) return null; // URL é opcional
      final regex = RegExp(
        r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
      );
      if (!regex.hasMatch(value.trim())) {
        return message ?? 'URL inválida';
      }
      return null;
    };
  }

  /// Número inteiro positivo
  static String? Function(String?) positiveInt([String? message]) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return message ?? 'Valor é obrigatório';
      }
      final n = int.tryParse(value.trim());
      if (n == null || n <= 0) {
        return message ?? 'Deve ser um número positivo';
      }
      return null;
    };
  }

  /// Número dentro de um range
  static String? Function(String?) numberRange(int min, int max,
      [String? message]) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return 'Valor é obrigatório';
      }
      final n = int.tryParse(value.trim());
      if (n == null || n < min || n > max) {
        return message ?? 'Deve ser entre $min e $max';
      }
      return null;
    };
  }

  /// Combinar múltiplos validadores
  static String? Function(String?) compose(
      List<String? Function(String?)> validators) {
    return (value) {
      for (final validator in validators) {
        final result = validator(value);
        if (result != null) return result;
      }
      return null;
    };
  }
}
